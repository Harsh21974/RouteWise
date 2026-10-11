package com.routewise.api.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Request body of {@code POST /api/deliveries/ocr}: raw text extracted from a
 * label photo by OCR. {@code orderId} is optional.
 */
public record OcrDeliveryRequest(
        @NotBlank(message = "rawText is required") String rawText,
        String orderId) {
}