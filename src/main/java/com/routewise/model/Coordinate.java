package com.routewise.model;

/**
 * A geographic point expressed in WGS-84 degrees.
 *
 * <p>Field order is deliberately {@code (longitude, latitude)} because OSRM
 * expects coordinates as {@code lon,lat}. Passing the wrong order is a classic
 * source of "impossible route" bugs, so the longitudes come first here to
 * match the OSRM URL format directly.
 *
 * @param longitude geographic longitude (x axis), in degrees
 * @param latitude  geographic latitude (y axis), in degrees
 */
public record Coordinate(double longitude, double latitude) {
}