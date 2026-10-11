package com.routewise.error;

/**
 * Raised when a request is semantically invalid. Mapped to HTTP 400.
 */
public class BadRequestException extends RuntimeException {

    public BadRequestException(String message) {
        super(message);
    }
}