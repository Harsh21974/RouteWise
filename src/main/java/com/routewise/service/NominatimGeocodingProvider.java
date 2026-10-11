package com.routewise.service;

import com.routewise.error.GeocodingException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Optional;

/**
 * Default {@link GeocodingProvider}: OSM Nominatim.
 *
 * <p>Nominatim TOS require a {@code User-Agent} that identifies the
 * application; supply one via {@code geocoding.user-agent}. An optional
 * {@code geocoding.country-codes} ISO-3166-1 list (e.g. {@code in,au})
 * restricts results.
 */
@Component
class NominatimGeocodingProvider implements GeocodingProvider {

    private static final Logger log = LoggerFactory.getLogger(NominatimGeocodingProvider.class);

    private final RestClient restClient;
    private final String baseUrl;
    private final String countryCodes;

    NominatimGeocodingProvider(
            @Value("${geocoding.base-url:https://nominatim.openstreetmap.org}") String baseUrl,
            @Value("${geocoding.user-agent:RouteWise/0.1}") String userAgent,
            @Value("${geocoding.country-codes:}") String countryCodes) {
        this.baseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        this.countryCodes = countryCodes == null ? "" : countryCodes.trim();
        this.restClient = RestClient.builder()
                .defaultHeader("User-Agent", userAgent)
                .build();
    }

    @Override
    public Optional<GeocodeResult> geocode(String address) {
        if (address == null || address.isBlank()) {
            return Optional.empty();
        }
        StringBuilder params = new StringBuilder();
        params.append("format=json&addressdetails=0&limit=1&q=")
              .append(URLEncoder.encode(address, StandardCharsets.UTF_8));
        if (!countryCodes.isEmpty()) {
            params.append("&countrycodes=").append(URLEncoder.encode(countryCodes, StandardCharsets.UTF_8));
        }

        String url = baseUrl + "/search?" + params;
        try {
            NominatimPlace[] places = restClient.get()
                    .uri(URI.create(url))
                    .retrieve()
                    .body(NominatimPlace[].class);

            if (places == null || places.length == 0) {
                log.debug("No Nominatim result for address: {}", address);
                return Optional.empty();
            }
            NominatimPlace place = places[0];
            return Optional.of(new GeocodeResult(
                    Double.parseDouble(place.lat()),
                    Double.parseDouble(place.lon()),
                    place.display_name()));
        } catch (RestClientException e) {
            throw new GeocodingException("Geocoding provider request failed: " + e.getMessage(), e);
        }
    }

    /** Nominatim JSON response object (minimal fields). */
    private record NominatimPlace(String lat, String lon, String display_name) {
    }
}