package com.routewise.service;

import com.routewise.error.BadRequestException;
import com.routewise.error.NotFoundException;
import com.routewise.model.Delivery;
import com.routewise.model.DeliveryStatus;
import com.routewise.model.GeocodeStatus;
import com.routewise.repository.DeliveryRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DeliveryServiceTest {

    @Mock
    private DeliveryRepository deliveryRepository;

    private DeliveryService service() {
        return new DeliveryService(deliveryRepository);
    }

    private Delivery savedDelivery(long id) {
        Delivery d = new Delivery();
        d.setId(id);
        d.setStatus(DeliveryStatus.PENDING);
        d.setGeocodeStatus(GeocodeStatus.NOT_GEOCODED);
        d.setRawAddress("Test");
        return d;
    }

    @Test
    void updateCoordinatesSetsConfirmedStatus() {
        when(deliveryRepository.findById(1L)).thenReturn(Optional.of(savedDelivery(1L)));
        when(deliveryRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        Delivery d = service().updateCoordinates(1L, 12.5, 77.3);

        assertEquals(GeocodeStatus.CONFIRMED, d.getGeocodeStatus());
        assertEquals(12.5, d.getLatitude());
        assertEquals(77.3, d.getLongitude());
    }

    @Test
    void updateCoordinatesRejectsLatitudeOutOfRange() {
        assertThrows(BadRequestException.class, () -> service().updateCoordinates(1L, 91.0, 77.0));
        assertThrows(BadRequestException.class, () -> service().updateCoordinates(1L, -91.0, 77.0));
    }

    @Test
    void updateCoordinatesRejectsLongitudeOutOfRange() {
        assertThrows(BadRequestException.class, () -> service().updateCoordinates(1L, 12.0, 181.0));
        assertThrows(BadRequestException.class, () -> service().updateCoordinates(1L, 12.0, -181.0));
    }

    @Test
    void updateCoordinatesMissingDeliveryNotFound() {
        when(deliveryRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(NotFoundException.class, () -> service().updateCoordinates(99L, 12.0, 77.0));
        assertThrows(NotFoundException.class, () -> service().updateCoordinates(99L, 12.0, 77.0));
    }
}