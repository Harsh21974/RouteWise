package com.routewise.error;

/**
 * Raised when the OR-Tools solver fails to produce a feasible route, or when
 * the OSRM matrix is inconsistent with the request. Mapped to HTTP 500.
 */
public class OptimizationException extends RuntimeException {

    public OptimizationException(String message) {
        super(message);
    }
}