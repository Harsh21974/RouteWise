package com.routewise.service;

import com.routewise.api.dto.DeliveryIntakeResponse;
import com.routewise.api.dto.ManualDeliveryRequest;
import com.routewise.error.BadRequestException;
import com.routewise.error.NotFoundException;
import com.routewise.model.Delivery;
import com.routewise.model.GeocodeStatus;
import com.routewise.model.Order;
import com.routewise.repository.DeliveryRepository;
import com.routewise.repository.OrderRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Unit tests for the parcel-intake service (scan / ocr / manual).
 */
@ExtendWith(MockitoExtension.class)
class DeliveryIntakeServiceTest {

    @Mock
    private DeliveryRepository deliveryRepository;
    @Mock
    private OrderRepository orderRepository;

    private DeliveryIntakeService service() {
        return new DeliveryIntakeService(deliveryRepository, orderRepository);
    }

    private void saveReturnsTheEntity() {
        when(deliveryRepository.save(any(Delivery.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));
    }

    @Test
    void scanCreatesGeocodedDeliveryFromOrderLookup() {
        saveReturnsTheEntity();
        Order order = new Order();
        order.setId(7L);
        order.setOrderId("ORD-100");
        order.setRawAddress("42 Main Road, Hyderabad, 500034");
        order.setLatitude(17.4);
        order.setLongitude(78.4);
        when(orderRepository.findByOrderId("ORD-100")).thenReturn(Optional.of(order));

        DeliveryIntakeResponse response = service().scan("ORD-100");

        assertEquals("SCAN", response.source());
        assertNull(response.parsedAddress());
        assertEquals("ORD-100", response.delivery().orderId());
        assertEquals(17.4, response.delivery().latitude());
        assertEquals(78.4, response.delivery().longitude());
        assertEquals(GeocodeStatus.GEOCODED, response.delivery().geocodeStatus());
        verify(deliveryRepository).save(any(Delivery.class));
    }

    @Test
    void scanUnknownOrderThrowsNotFoundAndDoesNotPersist() {
        when(orderRepository.findByOrderId("NOPE")).thenReturn(Optional.empty());

        assertThrows(NotFoundException.class, () -> service().scan("NOPE"));
        verify(deliveryRepository, never()).save(any(Delivery.class));
    }

    @Test
    void scanOrderWithoutCoordinatesYieldsNotGeocoded() {
        saveReturnsTheEntity();
        Order order = new Order();
        order.setOrderId("ORD-200");
        order.setRawAddress("Somewhere");
        when(orderRepository.findByOrderId("ORD-200")).thenReturn(Optional.of(order));

        DeliveryIntakeResponse response = service().scan("ORD-200");

        assertEquals(GeocodeStatus.NOT_GEOCODED, response.delivery().geocodeStatus());
        assertNull(response.delivery().latitude());
    }

    @Test
    void ocrCreatesNotGeocodedDeliveryAndReturnsParsedAddress() {
        saveReturnsTheEntity();

        DeliveryIntakeResponse response = service().ocr(
                "PLOT 8, SRI NAGAR COLONY\nHYDERABAD 500034", null);

        assertEquals("OCR", response.source());
        assertNotNull(response.parsedAddress());
        assertEquals("500034", response.parsedAddress().pincode());
        assertEquals("Hyderabad", response.parsedAddress().city());
        assertEquals(GeocodeStatus.NOT_GEOCODED, response.delivery().geocodeStatus());
        assertNull(response.delivery().orderId());
        assertEquals(response.parsedAddress().displayText(), response.delivery().rawAddress());
    }

    @Test
    void ocrKeepsRawTextWhenNothingIsParseable() {
        saveReturnsTheEntity();

        DeliveryIntakeResponse response = service().ocr("##%^&&**", null);

        assertEquals("##%^&&**", response.delivery().rawAddress());
        assertEquals(GeocodeStatus.NOT_GEOCODED, response.delivery().geocodeStatus());
    }

    @Test
    void manualCreatesNotGeocodedDelivery() {
        saveReturnsTheEntity();

        DeliveryIntakeResponse response = service().manual(new ManualDeliveryRequest(
                "ORD-9", "42 Main Road", "Banjara Hills", "Hyderabad", "500034"));

        assertEquals("MANUAL", response.source());
        assertEquals("ORD-9", response.delivery().orderId());
        assertEquals("42 Main Road, Banjara Hills, Hyderabad, 500034",
                response.delivery().rawAddress());
        assertEquals(GeocodeStatus.NOT_GEOCODED, response.delivery().geocodeStatus());
        assertNull(response.delivery().latitude());
    }

    @Test
    void manualRejectsBlankAddress() {
        assertThrows(BadRequestException.class, () -> service().manual(
                new ManualDeliveryRequest("ORD-1", " ", null, "", "   ")));
        verify(deliveryRepository, never()).save(any(Delivery.class));
    }
}