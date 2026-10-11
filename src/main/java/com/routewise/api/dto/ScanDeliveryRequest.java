package com.routewise.api.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Request body of {@code POST /api/deliveries/scan}: the barcode/QR payload.
 */
public record ScanDeliveryRequest(
        @NotBlank(message = "orderId is required") String orderId) {
}