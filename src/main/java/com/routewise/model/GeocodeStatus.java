package com.routewise.model;

/**
 * How a delivery's coordinates were (or were not) determined.
 */
public enum GeocodeStatus {

    /** Captured by OCR or manual entry; no coordinates resolved yet. */
    NOT_GEOCODED,

    /** Best-guess coordinates produced by the geocoding provider; the pin has
     *  not been visually verified yet and may need driver confirmation. */
    AUTO_GEOCODED,

    /** Coordinates verified (or corrected) by a user/driver. Fully routable. */
    CONFIRMED,

    /** Coordinates taken from an authoritative source (e.g. the orders table
     *  during barcode scan). Treated as verified, like {@link #CONFIRMED}. */
    GEOCODED,

    /** The provider could not resolve the address into coordinates. */
    GEOCODING_FAILED
}