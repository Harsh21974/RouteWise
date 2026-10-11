package com.routewise;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Entry point of the RouteWise core backend.
 *
 * <p>This service exposes the (locked) optimization pipeline:
 * OSRM matrix computation + OR-Tools single-vehicle TSP solve.
 */
@SpringBootApplication
public class RouteWiseApplication {

    public static void main(String[] args) {
        SpringApplication.run(RouteWiseApplication.class, args);
    }
}