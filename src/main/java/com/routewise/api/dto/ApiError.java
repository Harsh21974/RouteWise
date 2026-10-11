package com.routewise.api.dto;

import java.time.Instant;

/**
 * Uniform error body returned by the API.
 */
public record ApiError(Instant timestamp, int status, String error, String message) {
}