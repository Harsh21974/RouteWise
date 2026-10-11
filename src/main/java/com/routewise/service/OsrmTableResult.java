package com.routewise.service;

import com.routewise.model.Coordinate;

/**
 * Result of an OSRM {@code /table} call: the NxN matrices of travel times
 * (seconds) and distances (meters). Entries can be {@code null} for
 * unreachable point pairs.
 *
 * @param durations NxN matrix of travel time in seconds, or null where unreachable
 * @param distances NxN matrix of travel distance in meters, or null where unreachable
 */
public record OsrmTableResult(Double[][] durations, Double[][] distances) {
}