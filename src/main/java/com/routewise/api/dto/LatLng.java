package com.routewise.api.dto;

/**
 * A WGS-84 point exposed to clients (latitude/longitude order, as most map
 * SDKs and humans expect).
 */
public record LatLng(double latitude, double longitude) {
}