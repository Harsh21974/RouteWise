package com.routewise.api;

import com.routewise.api.dto.CreateDeliveryRequest;
import com.routewise.api.dto.DeliveryDto;
import com.routewise.api.dto.DeliveryIntakeResponse;
import com.routewise.api.dto.ManualDeliveryRequest;
import com.routewise.api.dto.OcrDeliveryRequest;
import com.routewise.api.dto.ScanDeliveryRequest;
import com.routewise.api.dto.UpdateCoordinatesRequest;
import com.routewise.api.dto.UpdateDeliveryStatusRequest;
import com.routewise.service.DeliveryIntakeService;
import com.routewise.service.DeliveryService;
import com.routewise.service.GeocodingService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Delivery lifecycle endpoints.
 */
@RestController
@RequestMapping("/api/deliveries")
public class DeliveriesController {

    private final DeliveryService deliveryService;
    private final DeliveryIntakeService deliveryIntakeService;
    private final GeocodingService geocodingService;

    public DeliveriesController(
            DeliveryService deliveryService,
            DeliveryIntakeService deliveryIntakeService,
            GeocodingService geocodingService) {
        this.deliveryService = deliveryService;
        this.deliveryIntakeService = deliveryIntakeService;
        this.geocodingService = geocodingService;
    }

    /** Creates a new parcel (seed data for optimization). */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public DeliveryDto create(@Valid @RequestBody CreateDeliveryRequest request) {
        return DeliveryDto.from(deliveryService.create(
                request.orderId(), request.rawAddress(), request.latitude(), request.longitude()));
    }

    /** Barcode intake: looks the order up; 404 signals the client to fall back. */
    @PostMapping("/scan")
    @ResponseStatus(HttpStatus.CREATED)
    public DeliveryIntakeResponse scan(@Valid @RequestBody ScanDeliveryRequest request) {
        return deliveryIntakeService.scan(request.orderId());
    }

    /** OCR intake: parses raw label text into a structured address. */
    @PostMapping("/ocr")
    @ResponseStatus(HttpStatus.CREATED)
    public DeliveryIntakeResponse ocr(@Valid @RequestBody OcrDeliveryRequest request) {
        return deliveryIntakeService.ocr(request.rawText(), request.orderId());
    }

    /** Manual intake: typed structured address. */
    @PostMapping("/manual")
    @ResponseStatus(HttpStatus.CREATED)
    public DeliveryIntakeResponse manual(@Valid @RequestBody ManualDeliveryRequest request) {
        return deliveryIntakeService.manual(request);
    }

    /** Marks a delivery as DELIVERED or SKIPPED. */
    @PatchMapping("/{id}/status")
    public DeliveryDto updateStatus(
            @PathVariable("id") Long id,
            @Valid @RequestBody UpdateDeliveryStatusRequest request) {
        return DeliveryDto.from(deliveryService.updateStatus(id, request.status()));
    }

    /** Best-effort auto-geocode via the configured provider. */
    @PostMapping("/{id}/geocode")
    public DeliveryDto geocode(@PathVariable("id") Long id) {
        return DeliveryDto.from(geocodingService.geocodeDelivery(id));
    }

    /** Manual pin correction (driver dragged the marker on the map). */
    @PatchMapping("/{id}/coordinates")
    public DeliveryDto updateCoordinates(
            @PathVariable("id") Long id,
            @Valid @RequestBody UpdateCoordinatesRequest request) {
        return DeliveryDto.from(deliveryService.updateCoordinates(id, request.latitude(), request.longitude()));
    }
}