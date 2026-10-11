package com.routewise.model;

/**
 * Lifecycle state of a planned Route.
 */
public enum RouteStatus {
    /** Route has been optimized and saved, not yet started. */
    PLANNED,
    /** Driver is currently working through the route. */
    ACTIVE,
    /** Driver finished / delivered everything relevant. */
    COMPLETED
}