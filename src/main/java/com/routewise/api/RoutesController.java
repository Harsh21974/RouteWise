package com.routewise.api;

import com.routewise.api.dto.OptimizeRouteRequest;
import com.routewise.api.dto.OptimizeRouteResponse;
import com.routewise.service.RouteService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Route planning endpoints.
 */
@RestController
@RequestMapping("/api/routes")
public class RoutesController {

    private final RouteService routeService;

    public RoutesController(RouteService routeService) {
        this.routeService = routeService;
    }

    /**
     * Runs the full optimization pipeline (OSRM matrix + OR-Tools TSP +
     * directions), persists the route and returns the visiting order,
     * geometry and totals.
     */
    @PostMapping("/optimize")
    @ResponseStatus(HttpStatus.CREATED)
    public OptimizeRouteResponse optimize(@Valid @RequestBody OptimizeRouteRequest request) {
        return routeService.planRoute(request);
    }

    /** Fetches a previously saved route with its geometry. */
    @GetMapping("/{id}")
    public OptimizeRouteResponse get(@PathVariable("id") Long id) {
        return routeService.getRoute(id);
    }
}