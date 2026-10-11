package com.routewise.service;

import com.routewise.api.dto.CreateOrderRequest;
import com.routewise.api.dto.OrderDto;
import com.routewise.error.BadRequestException;
import com.routewise.model.Order;
import com.routewise.repository.OrderRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.StringJoiner;

/**
 * CRUD for the orders table the barcode-scan intake flow looks up. Minimal by
 * design: it exists so scanned parcels can be created without re-typing
 * address and coordinates.
 */
@Service
public class OrderService {

    private final OrderRepository orderRepository;

    public OrderService(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    @Transactional
    public OrderDto create(CreateOrderRequest request) {
        String orderId = request.orderId().trim();
        orderRepository.findByOrderId(orderId)
                .ifPresent(existing -> {
                    throw new BadRequestException("Order " + orderId + " already exists.");
                });

        Order order = new Order();
        order.setOrderId(orderId);
        order.setStreet(trimToNull(request.street()));
        order.setArea(trimToNull(request.area()));
        order.setCity(trimToNull(request.city()));
        order.setPincode(trimToNull(request.pincode()));
        order.setLatitude(request.latitude());
        order.setLongitude(request.longitude());
        order.setRawAddress(buildRawAddress(order));
        return OrderDto.from(orderRepository.save(order));
    }

    private static String buildRawAddress(Order order) {
        StringJoiner joiner = new StringJoiner(", ");
        for (String part : new String[]{
                order.getStreet(), order.getArea(), order.getCity(), order.getPincode()}) {
            if (part != null && !part.isBlank()) {
                joiner.add(part.trim());
            }
        }
        String joined = joiner.toString();
        return joined.isEmpty() ? null : joined;
    }

    private static String trimToNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }
}