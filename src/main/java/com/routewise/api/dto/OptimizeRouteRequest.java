package com.routewise.api.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.util.List;

/**
 * Request body of {@code POST /api/routes/optimize}.
 *
 * @param deliveryIds     the parcel IDs to order; at least one must be given
 * @param startLatitude   latitude of the driver's fixed start point (warehouse)
 * @param startLongitude  longitude of the driver's fixed start point (warehouse)
 * @param driverId        identifier of the driver the route is planned for
 */
public record OptimizeRouteRequest(
        @NotEmpty(message = "deliveryIds must contain at least one delivery") List<Long> deliveryIds,
        @NotNull(message = "startLatitude is required") Double startLatitude,
        @NotNull(message = "startLongitude is required") Double startLongitude,
        String driverId) {
}