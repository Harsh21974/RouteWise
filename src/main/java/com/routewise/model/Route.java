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

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

/**
 * A persisted, optimized delivery route for a single driver.
 *
 * <p>The {@code orderedDeliveryIds} column stores the visiting order produced
 * by the (locked) optimization pipeline as a JSON array in a Postgres
 * {@code jsonb} column. The start location is persisted as well so the driver
 * start leg can be re-rendered on later fetches.
 */
@Entity
@Table(name = "routes")
public class Route {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "driver_id", length = 100)
    private String driverId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private RouteStatus status = RouteStatus.PLANNED;

    /**
     * IDs of the deliveries in the order the driver should visit them,
     * produced by the optimization pipeline. Stored as jsonb.
     */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "ordered_delivery_ids", columnDefinition = "jsonb", nullable = false)
    private List<Long> orderedDeliveryIds = new ArrayList<>();

    /** Fixed starting location (warehouse) of the driver, — used to render the first leg. */
    @Column(name = "start_latitude")
    private Double startLatitude;

    @Column(name = "start_longitude")
    private Double startLongitude;

    @Column(name = "total_distance_meters")
    private Long totalDistanceMeters;

    @Column(name = "total_duration_seconds")
    private Long totalDurationSeconds;

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

    public String getDriverId() {
        return driverId;
    }

    public void setDriverId(String driverId) {
        this.driverId = driverId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public RouteStatus getStatus() {
        return status;
    }

    public void setStatus(RouteStatus status) {
        this.status = status;
    }

    public List<Long> getOrderedDeliveryIds() {
        return orderedDeliveryIds;
    }

    public void setOrderedDeliveryIds(List<Long> orderedDeliveryIds) {
        this.orderedDeliveryIds = orderedDeliveryIds == null ? new ArrayList<>() : orderedDeliveryIds;
    }

    public Double getStartLatitude() {
        return startLatitude;
    }

    public void setStartLatitude(Double startLatitude) {
        this.startLatitude = startLatitude;
    }

    public Double getStartLongitude() {
        return startLongitude;
    }

    public void setStartLongitude(Double startLongitude) {
        this.startLongitude = startLongitude;
    }

    public Long getTotalDistanceMeters() {
        return totalDistanceMeters;
    }

    public void setTotalDistanceMeters(Long totalDistanceMeters) {
        this.totalDistanceMeters = totalDistanceMeters;
    }

    public Long getTotalDurationSeconds() {
        return totalDurationSeconds;
    }

    public void setTotalDurationSeconds(Long totalDurationSeconds) {
        this.totalDurationSeconds = totalDurationSeconds;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) {
            return true;
        }
        if (!(o instanceof Route route)) {
            return false;
        }
        return id != null && Objects.equals(id, route.id);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id);
    }

    @Override
    public String toString() {
        return "Route{id=" + id + ", driverId='" + driverId + "', deliveries=" + orderedDeliveryIds.size() + "}";
    }
}