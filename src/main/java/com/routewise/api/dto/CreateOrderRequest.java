package com.routewise.api.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Request body of {@code POST /api/orders}.
 */
public record CreateOrderRequest(
        @NotBlank(message = "orderId is required") String orderId,
        String street,
        String area,
        String city,
        String pincode,
        Double latitude,
        Double longitude) {
}