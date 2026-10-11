package com.routewise.api.dto;

import com.routewise.model.Delivery;
import com.routewise.model.DeliveryStatus;
import com.routewise.model.GeocodeStatus;

/**
 * A delivery as exposed to API clients.  {@code requiresPinConfirmation}
 * is a convenience flag derived from the geocode status so the frontend
 * can visually warn a driver to double-check a pin that was auto-placed.
 */
public record DeliveryDto(
        Long id,
        String orderId,
        String rawAddress,
        Double latitude,
        Double longitude,
        DeliveryStatus status,
        GeocodeStatus geocodeStatus,
        boolean requiresPinConfirmation) {

    public static DeliveryDto from(Delivery delivery) {
        return new DeliveryDto(
                delivery.getId(),
                delivery.getOrderId(),
                delivery.getRawAddress(),
                delivery.getLatitude(),
                delivery.getLongitude(),
                delivery.getStatus(),
                delivery.getGeocodeStatus(),
                delivery.getGeocodeStatus() == GeocodeStatus.AUTO_GEOCODED);
    }
}