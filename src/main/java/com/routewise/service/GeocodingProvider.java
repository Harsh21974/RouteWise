package com.routewise.service;

import java.util.Optional;

/**
 * Abstraction over whatever geocoding backend is configured. The default
 * implementation is OSM Nominatim ({@link NominatimGeocodingProvider}); swap
 * the bean to point at any provider that returns a best-guess lat/lng.
 */
public interface GeocodingProvider {

    /**
     * Resolves a free-text address into a best-guess coordinate.
     *
     * @param address the raw address text (street, area, city, pincode, ...)
     * @return the top candidate, or empty when nothing usable was found
     * @throws GeocodingException if the provider is unreachable or misconfigured
     */
    Optional<GeocodeResult> geocode(String address);
}