package com.routewise.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * Request body of {@code POST /api/deliveries}.
 */
public record CreateDeliveryRequest(
        @NotBlank(message = "orderId is required") String orderId,
        String rawAddress,
        @NotNull(message = "latitude is required") Double latitude,
        @NotNull(message = "longitude is required") Double longitude) {
}