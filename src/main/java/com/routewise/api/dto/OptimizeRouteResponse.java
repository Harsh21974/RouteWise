package com.routewise.api.dto;

import com.routewise.model.RouteStatus;

import java.time.Instant;
import java.util.List;

/**
 * Full route response for both {@code POST /api/routes/optimize} and
 * {@code GET /api/routes/{id}}.
 *
 * @param routeId             persisted route id
 * @param driverId            driver the route belongs to
 * @param status              route lifecycle status
 * @param startLocation       driver start point the route was planned from
 * @param orderedDeliveries   deliveries in optimal visiting order
 * @param geometry            encoded polyline of the full driving path
 * @param totalDistanceMeters aggregated travel distance of the path
 * @param totalDurationSeconds aggregated travel time of the path
 * @param createdAt           when the route was created
 */
public record OptimizeRouteResponse(
        Long routeId,
        String driverId,
        RouteStatus status,
        LatLng startLocation,
        List<DeliveryDto> orderedDeliveries,
        String geometry,
        Long totalDistanceMeters,
        Long totalDurationSeconds,
        Instant createdAt) {
}