package com.routewise.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.Objects;

/**
 * A single parcel to be delivered.
 */
@Entity
@Table(name = "deliveries")
public class Delivery {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * External identifier of the parcel, as known to the ordering system.
     * Not unique by design (a parcel can be re-attempted later). Nullable
     * because OCR/manual intake may not know the order yet.
     */
    @Column(name = "order_id")
    private String orderId;

    /** Free-text address captured at intake. May not be geocoded yet. */
    @Column(name = "raw_address", length = 500)
    private String rawAddress;

    /** Null until the parcel address has been geocoded. */
    @Column(name = "latitude")
    private Double latitude;

    /** Null until the parcel address has been geocoded. */
    @Column(name = "longitude")
    private Double longitude;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private DeliveryStatus status = DeliveryStatus.PENDING;

    /** Coordinates availability for the parcel address. */
    @Enumerated(EnumType.STRING)
    @Column(name = "geocode_status", nullable = false, length = 20)
    private GeocodeStatus geocodeStatus = GeocodeStatus.NOT_GEOCODED;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getOrderId() {
        return orderId;
    }

    public void setOrderId(String orderId) {
        this.orderId = orderId;
    }

    public String getRawAddress() {
        return rawAddress;
    }

    public void setRawAddress(String rawAddress) {
        this.rawAddress = rawAddress;
    }

    public Double getLatitude() {
        return latitude;
    }

    public void setLatitude(Double latitude) {
        this.latitude = latitude;
    }

    public Double getLongitude() {
        return longitude;
    }

    public void setLongitude(Double longitude) {
        this.longitude = longitude;
    }

    public DeliveryStatus getStatus() {
        return status;
    }

    public void setStatus(DeliveryStatus status) {
        this.status = status;
    }

    public GeocodeStatus getGeocodeStatus() {
        return geocodeStatus;
    }

    public void setGeocodeStatus(GeocodeStatus geocodeStatus) {
        this.geocodeStatus = geocodeStatus;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) {
            return true;
        }
        if (!(o instanceof Delivery delivery)) {
            return false;
        }
        return id != null && Objects.equals(id, delivery.id);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id);
    }

    @Override
    public String toString() {
        return "Delivery{id=" + id + ", orderId='" + orderId + "'}";
    }
}