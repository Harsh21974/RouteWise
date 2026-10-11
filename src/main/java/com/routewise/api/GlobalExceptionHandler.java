package com.routewise.api;

import com.routewise.api.dto.ApiError;
import com.routewise.error.BadRequestException;
import com.routewise.error.GeocodingException;
import com.routewise.error.NotFoundException;
import com.routewise.error.OptimizationException;
import com.routewise.error.OsrmException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.Instant;
import java.util.stream.Collectors;

/**
 * Maps exceptions raised across the API to consistent JSON error bodies.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(NotFoundException.class)
    public ResponseEntity<ApiError> notFound(NotFoundException e) {
        return error(HttpStatus.NOT_FOUND, e.getMessage());
    }

    @ExceptionHandler(BadRequestException.class)
    public ResponseEntity<ApiError> badRequest(BadRequestException e) {
        return error(HttpStatus.BAD_REQUEST, e.getMessage());
    }

    /** The self-hosted OSRM instance is down or misbehaving. */
    @ExceptionHandler(OsrmException.class)
    public ResponseEntity<ApiError> osrmDown(OsrmException e) {
        return error(HttpStatus.BAD_GATEWAY, e.getMessage());
    }

    /** The external geocoding provider is unreachable or returned garbage. */
    @ExceptionHandler(GeocodingException.class)
    public ResponseEntity<ApiError> geocodingFailed(GeocodingException e) {
        return error(HttpStatus.BAD_GATEWAY, e.getMessage());
    }

    @ExceptionHandler(OptimizationException.class)
    public ResponseEntity<ApiError> optimizationFailed(OptimizationException e) {
        return error(HttpStatus.INTERNAL_SERVER_ERROR, e.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> validationFailed(MethodArgumentNotValidException e) {
        String message = e.getBindingResult().getFieldErrors().stream()
                .map(this::formatFieldError)
                .collect(Collectors.joining("; "));
        return error(HttpStatus.BAD_REQUEST, message);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiError> unreadableBody(HttpMessageNotReadableException e) {
        return error(HttpStatus.BAD_REQUEST, "Malformed request body: " + e.getMessage());
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> generic(Exception e) {
        return error(HttpStatus.INTERNAL_SERVER_ERROR, "Unexpected server error.");
    }

    private String formatFieldError(FieldError fieldError) {
        return fieldError.getField() + ": " + fieldError.getDefaultMessage();
    }

    private ResponseEntity<ApiError> error(HttpStatus status, String message) {
        ApiError body = new ApiError(Instant.now(), status.value(), status.getReasonPhrase(), message);
        return ResponseEntity.status(status).body(body);
    }
}