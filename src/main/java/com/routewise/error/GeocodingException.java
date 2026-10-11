package com.routewise.error;

/**
 * Raised when the geocoding provider is unreachable or returns malformed data.
 * Mapped to HTTP 502 Bad Gateway.
 */
public class GeocodingException extends RuntimeException {

    public GeocodingException(String message, Throwable cause) {
        super(message, cause);
    }

    public GeocodingException(String message) {
        super(message);
    }
}