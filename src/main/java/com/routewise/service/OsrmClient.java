package com.routewise.service;

import com.routewise.error.OsrmException;
import com.routewise.model.Coordinate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.net.URI;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Thin HTTP client for a self-hosted OSRM instance.
 *
 * <p>OSRM accepts a list of coordinates as {@code lon,lat;lon,lat;...} in the
 * URL path. We always drive (car profile, the v1/driving API) because the
 * delivery vehicle travels by road.
 *
 * <p>This class is part of the interface consumed by the locked optimization
 * pipeline and should be left unchanged once verified.
 */
@Service
public class OsrmClient {

    /** Base URL of the OSRM server, e.g. {@code http://localhost:5000}. */
    private final String baseUrl;
    private final RestClient restClient;

    public OsrmClient(@Value("${osrm.base-url}") String baseUrl) {
        this.baseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        this.restClient = RestClient.create();
    }

    /**
     * Computes the NxN travel-time and travel-distance matrices for the given
     * ordered list of coordinates (N = number of coordinates).
     *
     * @param coordinates points in the order that rows/columns will map to;
     *                    the caller decides the indexing (e.g. warehouse first)
     * @return the duration and distance matrices, or {@code null} entries for
     *         unreachable pairs
     * @throws OsrmException if OSRM is unreachable or returns an error
     */
    public OsrmTableResult fetchTable(List<Coordinate> coordinates) {
        if (coordinates == null || coordinates.isEmpty()) {
            throw new OsrmException("OSRM table request needs at least one coordinate.");
        }
        String coordinatePath = formatCoordinates(coordinates);
        String url = baseUrl + "/table/v1/driving/" + coordinatePath + "?annotations=duration,distance";

        try {
            OsrmWireModels.OsrmTableResponse response =
                    restClient.get().uri(URI.create(url)).retrieve().body(OsrmWireModels.OsrmTableResponse.class);
            if (response == null || !"Ok".equals(response.code())) {
                throw new OsrmException("OSRM table query failed with code: " + (response == null ? "null" : response.code()));
            }
            return new OsrmTableResult(response.durations(), response.distances());
        } catch (RestClientException e) {
            throw new OsrmException("OSRM table query failed: " + e.getMessage(), e);
        }
    }

    /**
     * Computes the driving geometry (encoded polyline) and totals for a path
     * that visits the given coordinates in the given order.
     *
     * @param orderedCoordinates the full path, including the driver start point
     * @return encoded polyline plus total distance/duration; an empty geometry
     *         is returned for paths with fewer than two points
     * @throws OsrmException if OSRM is unreachable or returns an error
     */
    public RouteGeometry fetchDirections(List<Coordinate> orderedCoordinates) {
        if (orderedCoordinates == null || orderedCoordinates.size() < 2) {
            return RouteGeometry.empty();
        }
        String coordinatePath = formatCoordinates(orderedCoordinates);
        String url = baseUrl + "/route/v1/driving/" + coordinatePath
                + "?overview=full&alternatives=false&steps=false&geometries=polyline";

        try {
            OsrmWireModels.OsrmRouteResponse response =
                    restClient.get().uri(URI.create(url)).retrieve().body(OsrmWireModels.OsrmRouteResponse.class);
            if (response == null || !"Ok".equals(response.code()) || response.routes() == null || response.routes().isEmpty()) {
                throw new OsrmException("OSRM route query failed with code: " + (response == null ? "null" : response.code()));
            }
            OsrmWireModels.OsrmRoute route = response.routes().get(0);
            return new RouteGeometry(
                    route.geometry() == null ? "" : route.geometry(),
                    route.distance() == null ? 0L : route.distance().longValue(),
                    route.duration() == null ? 0L : route.duration().longValue());
        } catch (RestClientException e) {
            throw new OsrmException("OSRM route query failed: " + e.getMessage(), e);
        }
    }

    /** Formats coordinates as the OSRM path element: {@code lon,lat;lon,lat;...}. */
    private String formatCoordinates(List<Coordinate> coordinates) {
        return coordinates.stream()
                .map(c -> c.longitude() + "," + c.latitude())
                .collect(Collectors.joining(";"));
    }
}