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
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Unit tests for the geocoding service; the HTTP layer is mocked via a
 * fake {@link GeocodingProvider} so no network is required.
 */
@ExtendWith(MockitoExtension.class)
class GeocodingServiceTest {

    @Mock
    private GeocodingProvider geocodingProvider;

    @Mock
    private DeliveryRepository deliveryRepository;

    private GeocodingService service() {
        return new GeocodingService(deliveryRepository, geocodingProvider);
    }

    private Delivery savedDelivery(long id, GeocodeStatus status) {
        Delivery d = new Delivery();
        d.setId(id);
        d.setOrderId("O" + id);
        d.setRawAddress("Some Street, Hyderabad");
        d.setStatus(DeliveryStatus.PENDING);
        d.setGeocodeStatus(status);
        return d;
    }

    private void saveReturnsTheEntity() {
        when(deliveryRepository.save(any(Delivery.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));
    }

    @Test
    void setsAutoGeocodedOnSuccess() {
        saveReturnsTheEntity();
        Delivery d = savedDelivery(1L, GeocodeStatus.NOT_GEOCODED);
        when(deliveryRepository.findById(1L)).thenReturn(Optional.of(d));
        when(geocodingProvider.geocode("Some Street, Hyderabad"))
                .thenReturn(Optional.of(new GeocodeResult(17.4, 78.5, "Some Street, Hyderabad, Telangana")));

        Delivery updated = service().geocodeDelivery(1L);

        assertEquals(GeocodeStatus.AUTO_GEOCODED, updated.getGeocodeStatus());
        assertEquals(17.4, updated.getLatitude());
        assertEquals(78.5, updated.getLongitude());
        verify(deliveryRepository).save(any(Delivery.class));
    }

    @Test
    void setsGecoingFailedWhenProviderReturnsEmpty() {
        saveReturnsTheEntity();
        Delivery d = savedDelivery(2L, GeocodeStatus.NOT_GEOCODED);
        when(deliveryRepository.findById(2L)).thenReturn(Optional.of(d));
        when(geocodingProvider.geocode(any())).thenReturn(Optional.empty());

        Delivery updated = service().geocodeDelivery(2L);

        assertEquals(GeocodeStatus.GEOCODING_FAILED, updated.getGeocodeStatus());
        assertNull(updated.getLatitude());
    }

    @Test
    void rejectsAlreadyResolvedDeliveries() {
        Delivery d = savedDelivery(3L, GeocodeStatus.CONFIRMED);
        when(deliveryRepository.findById(3L)).thenReturn(Optional.of(d));

        assertThrows(BadRequestException.class, () -> service().geocodeDelivery(3L));
        verify(deliveryRepository, never()).save(any(Delivery.class));
    }

    @Test
    void rejectsAutoGeocodedWhenAlreadySet() {
        Delivery d = savedDelivery(4L, GeocodeStatus.AUTO_GEOCODED);
        when(deliveryRepository.findById(4L)).thenReturn(Optional.of(d));

        assertThrows(BadRequestException.class, () -> service().geocodeDelivery(4L));
        verify(deliveryRepository, never()).save(any(Delivery.class));
    }

    @Test
    void missingDeliveryThrowsNotFound() {
        when(deliveryRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(NotFoundException.class, () -> service().geocodeDelivery(99L));
        verify(deliveryRepository, never()).save(any(Delivery.class));
    }

    @Test
    void reGeocodesAfterProviderFailure() {
        saveReturnsTheEntity();
        Delivery d = savedDelivery(5L, GeocodeStatus.GEOCODING_FAILED);
        when(deliveryRepository.findById(5L)).thenReturn(Optional.of(d));
        when(geocodingProvider.geocode("Some Street, Hyderabad"))
                .thenReturn(Optional.of(new GeocodeResult(17.0, 78.0, "Place")));

        Delivery updated = service().geocodeDelivery(5L);

        assertEquals(GeocodeStatus.AUTO_GEOCODED, updated.getGeocodeStatus());
        assertEquals(17.0, updated.getLatitude());
    }
}