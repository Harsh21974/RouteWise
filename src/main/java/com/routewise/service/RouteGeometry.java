package com.routewise.service;

/**
 * Result of an OSRM {@code /route} call for an already-ordered sequence of
 * points.
 *
 * @param geometry         encoded polyline (overview, full) of the driving path
 * @param distanceMeters   total driving distance of the path
 * @param durationSeconds  total driving time of the path
 */
public record RouteGeometry(String geometry, long distanceMeters, long durationSeconds) {

    /** Empty geometry, used when there are fewer than two points to route. */
    public static RouteGeometry empty() {
        return new RouteGeometry("", 0L, 0L);
    }
}