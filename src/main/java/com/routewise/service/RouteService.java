package com.routewise.service;

import com.routewise.api.dto.DeliveryDto;
import com.routewise.api.dto.LatLng;
import com.routewise.api.dto.OptimizeRouteRequest;
import com.routewise.api.dto.OptimizeRouteResponse;
import com.routewise.error.BadRequestException;
import com.routewise.error.NotFoundException;
import com.routewise.model.Coordinate;
import com.routewise.model.Delivery;
import com.routewise.model.GeocodeStatus;
import com.routewise.model.Route;
import com.routewise.repository.DeliveryRepository;
import com.routewise.repository.RouteRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Orchestrates the route pipeline: load deliveries, call the (locked)
 * optimization service, fetch display geometry, persist the route and build
 * the API response.
 */
@Service
public class RouteService {

    private final DeliveryRepository deliveryRepository;
    private final RouteRepository routeRepository;
    private final RouteOptimizerService routeOptimizerService;
    private final DirectionsService directionsService;
    private final boolean requireConfirmedGeocode;

    public RouteService(
            DeliveryRepository deliveryRepository,
            RouteRepository routeRepository,
            RouteOptimizerService routeOptimizerService,
            DirectionsService directionsService,
            @Value("${routing.require-confirmed-geocode:false}") boolean requireConfirmedGeocode) {
        this.deliveryRepository = deliveryRepository;
        this.routeRepository = routeRepository;
        this.routeOptimizerService = routeOptimizerService;
        this.directionsService = directionsService;
        this.requireConfirmedGeocode = requireConfirmedGeocode;
    }

    /**
     * Full optimization pipeline:
     * load parcels → OSRM matrix → OR-Tools TSP → directions → persist.
     */
    @Transactional
    public OptimizeRouteResponse planRoute(OptimizeRouteRequest request) {
        List<Delivery> deliveries = deliveryRepository.findAllById(request.deliveryIds());
        if (deliveries.size() != request.deliveryIds().size()) {
            throw new BadRequestException("Some delivery IDs do not exist: "
                    + missingIds(request.deliveryIds(), deliveries));
        }
        List<Long> notGeocoded = deliveries.stream()
                .filter(d -> d.getLatitude() == null || d.getLongitude() == null)
                .map(Delivery::getId)
                .toList();
        if (!notGeocoded.isEmpty()) {
            throw new BadRequestException("Deliveries have not been geocoded yet and cannot be routed: "
                    + notGeocoded);
        }
        if (requireConfirmedGeocode) {
            List<Long> unconfirmed = deliveries.stream()
                    .filter(d -> d.getGeocodeStatus() == GeocodeStatus.AUTO_GEOCODED)
                    .map(Delivery::getId)
                    .toList();
            if (!unconfirmed.isEmpty()) {
                throw new BadRequestException(
                        "Deliveries have not had their pin confirmed yet. "
                                + "The driver should double-check the location and confirm it: " + unconfirmed);
            }
        }

        Coordinate warehouse = new Coordinate(request.startLongitude(), request.startLatitude());
        SolvedRoute solved = routeOptimizerService.optimize(warehouse, deliveries);
        RouteGeometry geometry = directionsService.fetchGeometry(solved.routeCoordinates());

        Route route = new Route();
        route.setDriverId(request.driverId());
        route.setStartLatitude(request.startLatitude());
        route.setStartLongitude(request.startLongitude());
        route.setOrderedDeliveryIds(solved.orderedDeliveryIds());
        route.setTotalDistanceMeters(solved.totalDistanceMeters());
        route.setTotalDurationSeconds(solved.totalDurationSeconds());
        route = routeRepository.save(route);

        return toResponse(route, solved.orderedDeliveries(), geometry);
    }

    /**
     * Fetches a persisted route and re-renders its driving geometry using the
     * stored visiting order and start point (the route itself is immutable;
     * only display data is recomputed).
     */
    @Transactional(readOnly = true)
    public OptimizeRouteResponse getRoute(Long routeId) {
        Route route = routeRepository.findById(routeId)
                .orElseThrow(() -> new NotFoundException("Route " + routeId + " not found."));

        List<Delivery> deliveries = loadInStoredOrder(route);
        RouteGeometry geometry = directionsService.fetchGeometry(buildCoordinates(route, deliveries));
        return toResponse(route, deliveries, geometry);
    }

    /** Loads the entities and keeps them in the stored visiting order. */
    private List<Delivery> loadInStoredOrder(Route route) {
        List<Long> ids = route.getOrderedDeliveryIds();
        if (ids.isEmpty()) {
            return List.of();
        }
        Map<Long, Delivery> byId = deliveryRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(Delivery::getId, Function.identity()));
        return ids.stream().map(byId::get).filter(Objects::nonNull).toList();
    }

    /** Warehouse + deliveries, in visiting order, for rendering the geometry. */
    private List<Coordinate> buildCoordinates(Route route, List<Delivery> deliveries) {
        List<Coordinate> coordinates = new ArrayList<>();
        if (route.getStartLatitude() != null && route.getStartLongitude() != null) {
            coordinates.add(new Coordinate(route.getStartLongitude(), route.getStartLatitude()));
        }
        for (Delivery delivery : deliveries) {
            if (delivery.getLatitude() != null && delivery.getLongitude() != null) {
                coordinates.add(new Coordinate(delivery.getLongitude(), delivery.getLatitude()));
            }
        }
        return coordinates;
    }

    private List<Long> missingIds(List<Long> requested, List<Delivery> found) {
        List<Long> foundIds = found.stream().map(Delivery::getId).toList();
        return requested.stream().filter(id -> !foundIds.contains(id)).toList();
    }

    private OptimizeRouteResponse toResponse(Route route, List<Delivery> orderedDeliveries, RouteGeometry geometry) {
        LatLng startLocation = (route.getStartLatitude() != null && route.getStartLongitude() != null)
                ? new LatLng(route.getStartLatitude(), route.getStartLongitude())
                : null;
        return new OptimizeRouteResponse(
                route.getId(),
                route.getDriverId(),
                route.getStatus(),
                startLocation,
                orderedDeliveries.stream().map(DeliveryDto::from).toList(),
                geometry.geometry(),
                route.getTotalDistanceMeters(),
                route.getTotalDurationSeconds(),
                route.getCreatedAt());
    }
}