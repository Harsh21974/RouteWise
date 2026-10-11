package com.routewise.api.dto;

import com.routewise.model.DeliveryStatus;
import jakarta.validation.constraints.NotNull;

/**
 * Request body of {@code PATCH /api/deliveries/{id}/status}.
 */
public record UpdateDeliveryStatusRequest(
        @NotNull(message = "status is required") DeliveryStatus status) {
}