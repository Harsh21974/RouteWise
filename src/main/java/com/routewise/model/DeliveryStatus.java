package com.routewise.model;

/**
 * Lifecycle state of a single parcel/delivery.
 */
public enum DeliveryStatus {
    /** Not yet attempted. */
    PENDING,
    /** Successfully handed over. */
    DELIVERED,
    /** Deliberately skipped (e.g. customer refused or closed). */
    SKIPPED
}