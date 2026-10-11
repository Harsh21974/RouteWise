package com.routewise.service;

import com.routewise.error.BadRequestException;
import com.routewise.error.NotFoundException;
import com.routewise.model.Delivery;
import com.routewise.model.DeliveryStatus;
import com.routewise.model.GeocodeStatus;
import com.routewise.repository.DeliveryRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

/**
 * Geocoding layer: turns a delivery's raw address into coordinates via the
 * configured {@link GeocodingProvider}.
 *
 * <p>Only parcels whose {@link GeocodeStatus} indicates they still need
 * coordinates (NOT_GEOCODED / GEOCODING_FAILED) may be geocoded. Once the
 * provider has produced a best guess, the coordinates are persisted with
 * status {@code AUTO_GEOCODED}; a missing result is recorded as
 * {@code GEOCODING_FAILED}.
 */
@Service
public class GeocodingService {

    private static final Logger log = LoggerFactory.getLogger(GeocodingService.class);

    private final DeliveryRepository deliveryRepository;
    private final GeocodingProvider geocodingProvider;

    public GeocodingService(DeliveryRepository deliveryRepository, GeocodingProvider geocodingProvider) {
        this.deliveryRepository = deliveryRepository;
        this.geocodingProvider = geocodingProvider;
    }

    /**
     * Best-effort auto-geocode. Only succeeds for deliveries that are
     * currently un-geocoded; already-resolved parcels are rejected with a 400
     * so the caller knows to use the manual coordinate endpoint instead.
     *
     * @return the updated delivery (never null)
     * @throws NotFoundException    if the delivery does not exist
     * @throws BadRequestException  if coordinates have already been set
     * @throws GeocodingException   if the provider is unreachable
     */
    @Transactional
    public Delivery geocodeDelivery(Long deliveryId) {
        Delivery delivery = deliveryRepository.findById(deliveryId)
                .orElseThrow(() -> new NotFoundException("Delivery " + deliveryId + " not found."));

        if (isResolved(delivery.getGeocodeStatus())) {
            throw new BadRequestException(
                    "Delivery " + deliveryId + " already has coordinates ("
                            + delivery.getGeocodeStatus() + "). Use PATCH /api/deliveries/"
                            + deliveryId + "/coordinates to correct them.");
        }

        Optional<GeocodeResult> result = geocodingProvider.geocode(delivery.getRawAddress());
        if (result.isPresent()) {
            GeocodeResult g = result.get();
            log.info("Geocoded delivery {} -> {},{}", deliveryId, g.latitude(), g.longitude());
            delivery.setLatitude(g.latitude());
            delivery.setLongitude(g.longitude());
            delivery.setGeocodeStatus(GeocodeStatus.AUTO_GEOCODED);
        } else {
            log.info("No geocode result for delivery {} (address: {})", deliveryId, delivery.getRawAddress());
            delivery.setGeocodeStatus(GeocodeStatus.GEOCODING_FAILED);
        }
        return deliveryRepository.save(delivery);
    }

    private static boolean isResolved(GeocodeStatus status) {
        return status == GeocodeStatus.CONFIRMED
                || status == GeocodeStatus.GEOCODED
                || status == GeocodeStatus.AUTO_GEOCODED;
    }
}