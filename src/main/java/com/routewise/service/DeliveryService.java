package com.routewise.service;

import com.routewise.error.BadRequestException;
import com.routewise.error.NotFoundException;
import com.routewise.model.Delivery;
import com.routewise.model.DeliveryStatus;
import com.routewise.model.GeocodeStatus;
import com.routewise.repository.DeliveryRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Delivery lifecycle operations.
 */
@Service
public class DeliveryService {

    private final DeliveryRepository deliveryRepository;

    public DeliveryService(DeliveryRepository deliveryRepository) {
        this.deliveryRepository = deliveryRepository;
    }

    /**
     * Creates a new parcel. Used to seed deliveries for optimization; address
     * capture / geocoding are out of scope and done elsewhere.
     */
    @Transactional
    public Delivery create(String orderId, String rawAddress, Double latitude, Double longitude) {
        Delivery delivery = new Delivery();
        delivery.setOrderId(orderId);
        delivery.setRawAddress(rawAddress);
        delivery.setLatitude(latitude);
        delivery.setLongitude(longitude);
        delivery.setStatus(DeliveryStatus.PENDING);
        delivery.setGeocodeStatus(GeocodeStatus.GEOCODED);
        return deliveryRepository.save(delivery);
    }

    /**
     * Marks a delivery as DELIVERED or SKIPPED.
     *
     * <p>A DELIVERED parcel is terminal: it cannot be reverted to SKIPPED.
     * SKIPPED parcels may still be marked DELIVERED later (driver returns to
     * an address or the parcel was hand-delivered on a follow-up visit).
     */
    @Transactional
    public Delivery updateStatus(Long deliveryId, DeliveryStatus newStatus) {
        if (newStatus == DeliveryStatus.PENDING) {
            throw new BadRequestException("Status must be DELIVERED or SKIPPED.");
        }
        Delivery delivery = deliveryRepository.findById(deliveryId)
                .orElseThrow(() -> new NotFoundException("Delivery " + deliveryId + " not found."));

        if (delivery.getStatus() == DeliveryStatus.DELIVERED && newStatus == DeliveryStatus.SKIPPED) {
            throw new BadRequestException("Delivery " + deliveryId + " is already DELIVERED and cannot be skipped.");
        }
        delivery.setStatus(newStatus);
        return deliveryRepository.save(delivery);
    }

    /**
     * Manually corrects a delivery's pin on the map (driver dragged the
     * marker). Coordinates are taken as authoritative; status becomes
     * {@link GeocodeStatus#CONFIRMED}.
     *
     * @throws BadRequestException if latitude / longitude are out of range
     * @throws NotFoundException   if the delivery does not exist
     */
    @Transactional
    public Delivery updateCoordinates(Long deliveryId, Double latitude, Double longitude) {
        if (latitude < -90 || latitude > 90) {
            throw new BadRequestException("Latitude must be between -90 and 90.");
        }
        if (longitude < -180 || longitude > 180) {
            throw new BadRequestException("Longitude must be between -180 and 180.");
        }
        Delivery delivery = deliveryRepository.findById(deliveryId)
                .orElseThrow(() -> new NotFoundException("Delivery " + deliveryId + " not found."));
        delivery.setLatitude(latitude);
        delivery.setLongitude(longitude);
        delivery.setGeocodeStatus(GeocodeStatus.CONFIRMED);
        return deliveryRepository.save(delivery);
    }
}