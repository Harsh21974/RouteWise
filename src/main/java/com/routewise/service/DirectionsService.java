package com.routewise.service;

import com.routewise.model.Coordinate;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Turns an already-optimized visiting order into the driving geometry used
 * for map display, by asking OSRM to trace the road network between the
 * ordered coordinates.
 */
@Service
public class DirectionsService {

    private final OsrmClient osrmClient;

    public DirectionsService(OsrmClient osrmClient) {
        this.osrmClient = osrmClient;
    }

    /**
     * Fetches the driving geometry for a path visiting {@code orderedCoordinates}.
     *
     * @param orderedCoordinates full path including the driver start point;
     *                           must be in visiting order
     * @return encoded polyline + totals, or an empty geometry when fewer than
     *         two points are given
     */
    public RouteGeometry fetchGeometry(List<Coordinate> orderedCoordinates) {
        if (orderedCoordinates == null || orderedCoordinates.size() < 2) {
            return RouteGeometry.empty();
        }
        return osrmClient.fetchDirections(orderedCoordinates);
    }
}