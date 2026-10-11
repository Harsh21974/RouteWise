package com.routewise.service;

import com.google.ortools.Loader;
import com.google.ortools.constraintsolver.Assignment;
import com.google.ortools.constraintsolver.FirstSolutionStrategy;
import com.google.ortools.constraintsolver.LocalSearchMetaheuristic;
import com.google.ortools.constraintsolver.RoutingIndexManager;
import com.google.ortools.constraintsolver.RoutingModel;
import com.google.ortools.constraintsolver.RoutingSearchParameters;
import com.google.protobuf.Duration;
import com.routewise.error.OptimizationException;
import com.routewise.model.Coordinate;
import com.routewise.model.Delivery;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

import static com.google.ortools.constraintsolver.main.defaultRoutingSearchParameters;

/**
 * THE CORE OPTIMIZATION SERVICE — treats parcels as a single-vehicle TSP.
 *
 * <p>Pipeline (this is the LOCKED interface the rest of the system consumes):
 * <ol>
 *   <li>Build the distance/time matrix via {@link OsrmClient#fetchTable}.</li>
 *   <li>Solve the TSP with Google OR-Tools: one vehicle, a fixed start point
 *       (the warehouse), no requirement to return to the depot.</li>
 * </ol>
 *
 * <p>Callers must never rely on how the model is built internally, only on the
 * {@link SolvedRoute} contract. Changing the solver configuration, matrix
 * logic, or algorithm here is forbidden unless explicitly requested.
 */
@Service
public class RouteOptimizerService {

    /**
     * Node index of the fixed start point (warehouse) in the OR-Tools model.
     * Delivery nodes occupy indices {@code 1..numDeliveries} in request order.
     */
    private static final int DEPOT_NODE = 0;

    /**
     * A huge time value given to point pairs OSRM reported as unreachable.
     * The solver then avoids them but still has a valid (if expensive) way to
     * connect any two points, keeping the model always feasible.
     */
    private static final long UNREACHABLE_FALLBACK_SECONDS = 100_000_000L;

    private final OsrmClient osrmClient;
    private final long timeLimitSeconds;

    public RouteOptimizerService(
            OsrmClient osrmClient,
            @Value("${solver.time-limit-seconds:10}") long timeLimitSeconds) {
        this.osrmClient = osrmClient;
        this.timeLimitSeconds = timeLimitSeconds;
    }

    static {
        // OR-Tools ships platform-specific native libraries (a DLL / dylib /
        // .so) inside the jar. They must be extracted and loaded exactly once
        // per JVM, before any RoutingModel is constructed.
        Loader.loadNativeLibraries();
    }

    /**
     * Computes the optimal visiting order for the given deliveries starting
     * from the fixed warehouse point.
     *
     * @param warehouse  fixed start point (driver's starting location)
     * @param deliveries the parcels to deliver; order in this list is irrelevant
     * @return the visiting order and the aggregated distance/duration of the path
     */
    public SolvedRoute optimize(Coordinate warehouse, List<Delivery> deliveries) {
        if (deliveries.isEmpty()) {
            return SolvedRoute.empty(warehouse);
        }

        // ---------------------------------------------------------------
        // 1) Coordinate indexing.
        //    node 0        = warehouse (fixed start)
        //    node 1..N     = the deliveries, in the order they were given
        //    OSRM matrix rows/columns follow the same indexing.
        // ---------------------------------------------------------------
        int numDeliveries = deliveries.size();
        int numNodes = numDeliveries + 1; // warehouse + deliveries

        List<Coordinate> coordinates = new ArrayList<>(numNodes);
        coordinates.add(warehouse);
        for (Delivery delivery : deliveries) {
            coordinates.add(new Coordinate(delivery.getLongitude(), delivery.getLatitude()));
        }

        // ---------------------------------------------------------------
        // 2) Distance/time matrix from OSRM.
        // ---------------------------------------------------------------
        OsrmTableResult table = osrmClient.fetchTable(coordinates);
        long[][] travelTimesSeconds = toCostMatrix(table.durations(), numNodes, "durations");
        long[][] travelDistancesMeters = toCostMatrix(table.distances(), numNodes, "distances");

        // ---------------------------------------------------------------
        // 3) Solve the TSP.
        // ---------------------------------------------------------------
        TspSolution tsp = solveTsp(numNodes, travelTimesSeconds, travelDistancesMeters);

        // Map the visited node indices back to the deliveries.
        List<Delivery> orderedDeliveries = new ArrayList<>(numDeliveries);
        List<Long> orderedIds = new ArrayList<>(numDeliveries);
        List<Coordinate> routeCoordinates = new ArrayList<>(numNodes);
        routeCoordinates.add(warehouse);
        for (int node : tsp.route) { // route excludes warehouse and the dummy end node
            Delivery delivery = deliveries.get(node - 1);
            orderedDeliveries.add(delivery);
            orderedIds.add(delivery.getId());
            routeCoordinates.add(new Coordinate(delivery.getLongitude(), delivery.getLatitude()));
        }

        return new SolvedRoute(orderedIds, orderedDeliveries, routeCoordinates,
                tsp.distanceMeters, tsp.durationSeconds);
    }

    /**
     * Solves the single-vehicle TSP.
     *
     * <p>OR-Tools' {@link RoutingModel} natively models tours that return to
     * the depot. We want an OPEN path: start at the warehouse, visit every
     * delivery once, and STAY at the last delivery (no return trip). The
     * standard technique is to append one dummy node and make it the vehicle's
     * END node. All arcs into/out of the dummy cost 0, so the solver freely
     * chooses the last real delivery and is never rewarded for driving back.
     *
     * <p>Arc costs are driving times (seconds); the distance matrix is used
     * only afterwards to report the travelled distance of the chosen path.
     *
     * @param numRealNodes   warehouse + deliveries (indices 0..numRealNodes-1)
     * @param durations      travel times (costs being minimized)
     * @param distances      travel distances (reported, not minimized)
     */
    private TspSolution solveTsp(int numRealNodes, long[][] durations, long[][] distances) {
        int dummyEndNode = numRealNodes; // one artificial node past the real ones

        // One vehicle with a FIXED start (DEPOT_NODE) and a FIXED end (dummy).
        RoutingIndexManager manager = new RoutingIndexManager(
                numRealNodes + 1,   // real nodes + dummy end node
                1,                  // one vehicle
                new int[]{DEPOT_NODE},
                new int[]{dummyEndNode});
        RoutingModel routing = new RoutingModel(manager);

        // Time to travel from one node to the next. Arcs touching the dummy
        // end node cost 0 so that "stop here" is free.
        int transitCallbackIndex = routing.registerTransitCallback((long sourceIndex, long destIndex) -> {
            int source = manager.indexToNode(sourceIndex);
            int dest = manager.indexToNode(destIndex);
            if (source == dummyEndNode || dest == dummyEndNode) {
                return 0L;
            }
            return durations[source][dest];
        });
        routing.setArcCostEvaluatorOfAllVehicles(transitCallbackIndex);

        // ---------------------------------------------------------------
        // Search strategy:
        //  - Start from OR-Tools' fully-populated DEFAULT parameters. A raw
        //    RoutingSearchParameters.newBuilder() leaves the local-search
        //    operator booleans UNSPECIFIED, which the solver rejects.
        //  - PATH_CHEAPEST_ARC builds a fast initial tour (greedy nearest
        //    neighbour), which alone is a solid heuristic for <= ~60 nodes.
        //  - If a time budget is configured, GUIDED_LOCAL_SEARCH further
        //    improves it; the more seconds, the better (but slower).
        //  - timeLimitSeconds == 0 keeps the solve effectively deterministic,
        //    which is convenient for tests.
        // ---------------------------------------------------------------
        RoutingSearchParameters.Builder searchParameters = defaultRoutingSearchParameters().toBuilder()
                .setFirstSolutionStrategy(FirstSolutionStrategy.Value.PATH_CHEAPEST_ARC);
        if (timeLimitSeconds > 0) {
            searchParameters
                    .setLocalSearchMetaheuristic(LocalSearchMetaheuristic.Value.GUIDED_LOCAL_SEARCH)
                    .setTimeLimit(Duration.newBuilder().setSeconds(timeLimitSeconds).build());
        }

        Assignment assignment = routing.solveWithParameters(searchParameters.build());
        if (assignment == null) {
            throw new OptimizationException("OR-Tools could not find a feasible route.");
        }

        // ---------------------------------------------------------------
        // Reconstruct the route by walking the solution's "next" chain from
        // the vehicle start until the (dummy) end node.
        //
        // Every visited real node is a stop -> recorded in the order.
        // Only the zero-cost arc that leads INTO the dummy end node is
        // skipped when accumulating travel totals.
        // ---------------------------------------------------------------
        List<Integer> route = new ArrayList<>();
        long totalDurationSeconds = 0L;
        long totalDistanceMeters = 0L;
        long index = routing.start(0);
        while (!routing.isEnd(index)) {
            int node = manager.indexToNode(index);
            if (node != DEPOT_NODE) {
                route.add(node); // a visited delivery, even if it is the last one
            }
            long nextIndex = assignment.value(routing.nextVar(index));
            int nextNode = manager.indexToNode(nextIndex);
            if (nextNode != dummyEndNode) {
                totalDurationSeconds += durations[node][nextNode];
                totalDistanceMeters += distances[node][nextNode];
            }
            index = nextIndex;
        }

        return new TspSolution(route, totalDistanceMeters, totalDurationSeconds);
    }

    /**
     * Converts the OSRM boxed matrix into a primitive {@code long[][]}, tuned
     * for the OR-Tools callback.
     *
     * <p>OSRM encodes "unreachable" as {@code null}. We replace such entries
     * with a large-but-finite sentinel based on the largest observed value in
     * the matrix, so the solver can still connect any two points but will
     * avoid unreachable pairs whenever a route exists.
     */
    private long[][] toCostMatrix(Double[][] raw, int expectedSize, String label) {
        if (raw == null || raw.length != expectedSize) {
            throw new OptimizationException("OSRM returned an unexpected " + label
                    + " matrix (expected " + expectedSize + "x" + expectedSize + ").");
        }

        long maxFinite = 0L;
        for (int i = 0; i < expectedSize; i++) {
            if (raw[i] == null || raw[i].length != expectedSize) {
                throw new OptimizationException("OSRM returned a ragged " + label + " matrix.");
            }
            for (int j = 0; j < expectedSize; j++) {
                Double value = raw[i][j];
                if (value != null && Double.isFinite(value) && value > 0) {
                    maxFinite = Math.max(maxFinite, (long) Math.ceil(value));
                }
            }
        }
        // Sentinel large enough that no feasible route prefers it, small
        // enough that long arithmetic cannot overflow when legs are summed.
        long unreachableCost = maxFinite > 0 ? maxFinite * expectedSize : UNREACHABLE_FALLBACK_SECONDS;

        long[][] matrix = new long[expectedSize][expectedSize];
        for (int i = 0; i < expectedSize; i++) {
            for (int j = 0; j < expectedSize; j++) {
                Double value = raw[i][j];
                matrix[i][j] = (value != null && Double.isFinite(value)) ? (long) Math.ceil(value) : unreachableCost;
            }
        }
        return matrix;
    }

    /** Internal outcome of the OR-Tools solve. */
    private record TspSolution(List<Integer> route, long distanceMeters, long durationSeconds) {
    }
}