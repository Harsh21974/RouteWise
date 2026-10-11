package com.routewise.api.dto;

/**
 * Request body of {@code POST /api/deliveries/manual}: a typed structured
 * address. At least one field must be present. {@code orderId} is optional.
 */
public record ManualDeliveryRequest(
        String orderId,
        String street,
        String area,
        String city,
        String pincode) {
}