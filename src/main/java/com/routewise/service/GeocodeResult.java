package com.routewise.service;

/**
 * A best-guess geocode result for an address: a point plus the provider's
 * human-readable place description (useful for letting a driver sanity-check
 * the pin before confirming it).
 */
public record GeocodeResult(double latitude, double longitude, String displayName) {
}