package com.routewise.api.dto;

import com.routewise.model.Order;

import java.time.Instant;

/**
 * An order as exposed to API clients (the barcode-scan lookup source).
 */
public record OrderDto(
        Long id,
        String orderId,
        String street,
        String area,
        String city,
        String pincode,
        String rawAddress,
        Double latitude,
        Double longitude,
        Instant createdAt) {

    public static OrderDto from(Order order) {
        return new OrderDto(
                order.getId(),
                order.getOrderId(),
                order.getStreet(),
                order.getArea(),
                order.getCity(),
                order.getPincode(),
                order.getRawAddress(),
                order.getLatitude(),
                order.getLongitude(),
                order.getCreatedAt());
    }
}