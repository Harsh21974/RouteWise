package com.routewise.api.dto;

import jakarta.validation.constraints.NotNull;

/**
 * Request body of {@code PATCH /api/deliveries/{id}/coordinates}.
 * Lat/lng are validated as sensible WGS-84 ranges in the service layer.
 */
public record UpdateCoordinatesRequest(
        @NotNull(message = "latitude is required") Double latitude,
        @NotNull(message = "longitude is required") Double longitude) {
}