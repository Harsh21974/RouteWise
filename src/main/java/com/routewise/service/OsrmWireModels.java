package com.routewise.service;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * JSON shapes returned by a self-hosted OSRM HTTP server.
 *
 * <p>These records are only used to deserialize OSRM responses; they are not
 * part of this service's public API.
 */
final class OsrmWireModels {

    private OsrmWireModels() {
    }

    /**
     * Response of {@code /table/v1/driving/{coordinates}}. {@code durations}
     * and {@code distances} are NxN matrices; individual entries may be
     * {@code null} when two points are mutually unreachable.
     */
    record OsrmTableResponse(
            @JsonProperty("code") String code,
            @JsonProperty("durations") Double[][] durations,
            @JsonProperty("distances") Double[][] distances,
            @JsonProperty("sources") List<OsrmWaypoint> sources,
            @JsonProperty("destinations") List<OsrmWaypoint> destinations) {
    }

    /** A single point in a table response: {@code location = [lon, lat]}. */
    record OsrmWaypoint(
            @JsonProperty("location") double[] location,
            @JsonProperty("hint") String hint,
            @JsonProperty("name") String name) {
    }

    /**
     * Response of {@code /route/v1/driving/{coordinates}}. With
     * {@code geometries=polyline} the geometry is an encoded polyline string
     * suitable for map display.
     */
    record OsrmRouteResponse(
            @JsonProperty("code") String code,
            @JsonProperty("routes") List<OsrmRoute> routes) {
    }

    record OsrmRoute(
            @JsonProperty("distance") Double distance,
            @JsonProperty("duration") Double duration,
            @JsonProperty("geometry") String geometry) {
    }
}