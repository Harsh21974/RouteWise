package com.routewise.service;

import com.routewise.model.Coordinate;
import com.routewise.model.Delivery;

import java.util.List;

/**
 * Outcome of the (locked) optimization pipeline: the visiting order of the
 * deliveries and the aggregate travel figures produced by OR-Tools.
 *
 * @param orderedDeliveryIds  delivery IDs in the order they should be visited
 * @param orderedDeliveries   the matching {@link Delivery} entities, in the same order
 * @param routeCoordinates    the full ordered path: warehouse first, then each delivery
 * @param totalDistanceMeters accumulated driving distance of the path
 * @param totalDurationSeconds accumulated driving time of the path
 */
public record SolvedRoute(
        List<Long> orderedDeliveryIds,
        List<Delivery> orderedDeliveries,
        List<Coordinate> routeCoordinates,
        long totalDistanceMeters,
        long totalDurationSeconds) {

    /** Result for an optimization run without any deliveries. */
    public static SolvedRoute empty(Coordinate warehouse) {
        return new SolvedRoute(List.of(), List.of(), List.of(warehouse), 0L, 0L);
    }
}