package com.routewise.api.dto;

/**
 * Result of a parcel-intake call: the created delivery plus which intake path
 * produced it and (for OCR/manual) the structured address.
 */
public record DeliveryIntakeResponse(
        DeliveryDto delivery,
        String source,
        ParsedAddress parsedAddress) {
}