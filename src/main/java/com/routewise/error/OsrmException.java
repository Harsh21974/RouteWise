package com.routewise.error;

/**
 * Raised when the self-hosted OSRM instance is unreachable or returns an
 * error. Mapped to HTTP 502 Bad Gateway, so the frontend can distinguish
 * "infrastructure down" from other failures.
 */
public class OsrmException extends RuntimeException {

    public OsrmException(String message) {
        super(message);
    }

    public OsrmException(String message, Throwable cause) {
        super(message, cause);
    }
}