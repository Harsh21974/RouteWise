package com.routewise.service;

import com.routewise.model.Coordinate;
import com.routewise.model.Delivery;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Unit tests for the locked optimization pipeline. Uses a synthetic OSRM
 * matrix (no server required) and a solver time limit of 0 seconds so the
 * first-solution strategy is fully deterministic.
 */
@ExtendWith(MockitoExtension.class)
class RouteOptimizerServiceTest {

    /**
     * Warehouse (0), then deliveries A(1), B(2), C(3). All travel costs are
     * intentionally asymmetric-free and plainly ordered so the greedy first
     * solution is also the obvious optimum: 0 -> A -> B -> C.
     */
    private static final double[][] TIMES = {
            {0, 10, 20, 100},
            {10, 0, 5, 50},
            {20, 5, 0, 30},
            {100, 50, 30, 0}
    };

    @Mock
    private OsrmClient osrmClient;

    private RouteOptimizerService optimizer() {
        return new RouteOptimizerService(osrmClient, 0L);
    }

    private Delivery delivery(long id, double lat, double lon) {
        Delivery d = new Delivery();
        d.setId(id);
        d.setOrderId("O" + id);
        d.setLatitude(lat);
        d.setLongitude(lon);
        return d;
    }

    private OsrmTableResult table(double[][] times, double[][] distances) {
        return new OsrmTableResult(box(times), box(distances));
    }

    private Double[][] box(double[][] values) {
        Double[][] boxed = new Double[values.length][values[0].length];
        for (int i = 0; i < values.length; i++) {
            for (int j = 0; j < values[i].length; j++) {
                Double v = values[i][j];
                boxed[i][j] = Double.isNaN(v) ? null : v;
            }
        }
        return boxed;
    }

    @Test
    void optimizesSimpleThreeDeliveryCase() {
        Coordinate warehouse = new Coordinate(0.0, 0.0);
        Delivery a = delivery(101L, 1.0, 1.0);
        Delivery b = delivery(102L, 2.0, 2.0);
        Delivery c = delivery(103L, 3.0, 3.0);
        List<Delivery> deliveries = List.of(a, b, c);

        when(osrmClient.fetchTable(anyList())).thenReturn(table(TIMES, TIMES));

        SolvedRoute solved = optimizer().optimize(warehouse, deliveries);

        assertEquals(List.of(101L, 102L, 103L), solved.orderedDeliveryIds());
        assertEquals(List.of(a, b, c), solved.orderedDeliveries());
        assertEquals(45L, solved.totalDurationSeconds());
        assertEquals(45L, solved.totalDistanceMeters());
        // Full path = warehouse first, then the deliveries in visiting order.
        assertEquals(1 + 3, solved.routeCoordinates().size());
        assertEquals(warehouse, solved.routeCoordinates().get(0));
    }

    @Test
    void handlesUnreachablePairsWithoutFailing() {
        // Warehouse <-> A are unreachable (null cost); the solver must route
        // around them through B: optimum 0 -> B -> A -> C = 20+5+10.
        double[][] times = {
                {0, Double.NaN, 20, 30},
                {Double.NaN, 0, 5, 10},
                {20, 5, 0, 30},
                {30, 10, 30, 0}
        };
        when(osrmClient.fetchTable(anyList())).thenReturn(table(times, times));

        SolvedRoute solved = optimizer().optimize(new Coordinate(0.0, 0.0), List.of(
                delivery(101L, 1.0, 1.0),
                delivery(102L, 2.0, 2.0),
                delivery(103L, 3.0, 3.0)));

        assertEquals(List.of(102L, 101L, 103L), solved.orderedDeliveryIds());
        assertEquals(35L, solved.totalDurationSeconds());
        assertEquals(35L, solved.totalDistanceMeters());
    }

    @Test
    void emptyDeliveryListDoesNotCallOsrm() {
        SolvedRoute solved = optimizer().optimize(new Coordinate(-73.9, 40.7), List.of());

        verify(osrmClient, never()).fetchTable(anyList());
        assertTrue(solved.orderedDeliveryIds().isEmpty());
        assertEquals(0L, solved.totalDurationSeconds());
        assertEquals(1, solved.routeCoordinates().size());
    }

    @Test
    void matrixSizeMismatchIsRejected() {
        when(osrmClient.fetchTable(anyList()))
                .thenReturn(new OsrmTableResult(box(TIMES), box(TIMES)));

        // Asked for 4 nodes but delivered 3 deliveries (warehouse+3 = 4
        // expected); give a 3x3... here TIMES is 4x4 and 3+1 nodes requested,
        // so no mismatch. Instead call with 2 deliveries to force expected 3.
        Delivery a = delivery(101L, 1.0, 1.0);
        Delivery b = delivery(102L, 2.0, 2.0);
        var thrown = org.junit.jupiter.api.Assertions.assertThrows(
                com.routewise.error.OptimizationException.class,
                () -> optimizer().optimize(new Coordinate(0.0, 0.0), List.of(a, b)));
        org.junit.jupiter.api.Assertions.assertTrue(
                thrown.getMessage().contains("unexpected durations matrix"));
    }
}