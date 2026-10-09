package com.wildlife.uc02.controller;

import com.wildlife.uc02.alert.event.AlertEvent;
import com.wildlife.uc02.alert.event.AlertEventPublisher;
import com.wildlife.uc02.dto.AlertSummaryResponse;
import com.wildlife.uc02.dto.AssignRangerRequest;
import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.exception.AlertNotFoundException;
import com.wildlife.uc02.exception.RangerNotFoundException;
import com.wildlife.uc02.repository.*;
import com.wildlife.uc02.service.api.AlertManager;
import com.wildlife.uc02.service.api.NotificationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;

/**
 * Controller for Park Managers to supervise alerts, review escalated incidents, and manually assign rangers.
 */
@Slf4j
@RestController
@RequestMapping("/api/manager")
@RequiredArgsConstructor
@Tag(name = "Park Manager Operations", description = "Endpoints for park managers to monitor geofences and reassign escalated alerts")
public class ManagerAlertController {

    private final AlertRepository alertRepository;
    private final GeofenceZoneRepository zoneRepository;
    private final RangerStatusRepository rangerStatusRepository;
    private final AlertAssignmentRepository assignmentRepository;
    private final AlertManager alertManager;
    private final NotificationService notificationService;
    private final AlertEventPublisher eventPublisher;
    private final Clock clock;

    @GetMapping("/alerts/escalated")
    @PreAuthorize("hasRole('MANAGER')")
    @Operation(summary = "Get escalated alerts", description = "Retrieves all alerts currently in ESCALATED state requiring manager intervention")
    public ResponseEntity<List<AlertSummaryResponse>> getEscalatedAlerts() {
        List<Alert> escalated = alertRepository.findByStatus(AlertStatus.ESCALATED);
        return ResponseEntity.ok(toSummaryList(escalated));
    }

    @PostMapping("/alerts/{id}/assign")
    @PreAuthorize("hasRole('MANAGER')")
    @Operation(summary = "Manually assign ranger to alert", description = "Assigns an available or standby ranger to an escalated alert, moving it to NOTIFIED")
    public ResponseEntity<Map<String, String>> manualAssign(
            @PathVariable String id,
            @RequestBody @Valid AssignRangerRequest request) {
        Alert alert = alertRepository.findById(id)
                .orElseThrow(() -> new AlertNotFoundException(id));

        RangerStatus ranger = rangerStatusRepository.findByUserId(request.getRangerId())
                .orElseThrow(() -> new RangerNotFoundException("Ranger not found: " + request.getRangerId()));

        alert.setAssignedRangerId(ranger.getUserId());
        alertRepository.save(alert);

        assignmentRepository.save(AlertAssignment.builder()
                .alertId(alert.getId())
                .rangerId(ranger.getUserId())
                .assignedAt(Instant.now(clock))
                .outcome(AssignmentOutcome.PENDING)
                .build());

        ranger.setAvailability(RangerAvailability.BUSY);
        rangerStatusRepository.save(ranger);

        alertManager.transitionAlert(alert, AlertStatus.NOTIFIED, "MANAGER", "Manually assigned by Park Manager");
        notificationService.notifyRanger(alert, ranger.getUserId());
        eventPublisher.publish(new AlertEvent(AlertEvent.Type.NOTIFIED, alert, ranger.getUserId()));

        return ResponseEntity.ok(Map.of(
                "message", "Alert assigned to ranger " + ranger.getUnitCode() + " successfully",
                "status", AlertStatus.NOTIFIED.name()
        ));
    }

    @GetMapping("/dashboard/alerts")
    @PreAuthorize("hasRole('MANAGER')")
    @Operation(summary = "Manager dashboard alerts overview", description = "Returns all system alerts for central command dashboard")
    public ResponseEntity<List<AlertSummaryResponse>> getAllDashboardAlerts() {
        List<Alert> allAlerts = alertRepository.findAll();
        return ResponseEntity.ok(toSummaryList(allAlerts));
    }

    @GetMapping("/geofences")
    @PreAuthorize("hasRole('MANAGER')")
    @Operation(summary = "List geofence zones", description = "Read-only list of all active geofence boundary polygons")
    public ResponseEntity<List<GeofenceZone>> getGeofenceZones() {
        List<GeofenceZone> zones = zoneRepository.findByActiveTrue();
        return ResponseEntity.ok(zones);
    }

    private List<AlertSummaryResponse> toSummaryList(List<Alert> alerts) {
        return alerts.stream().map(a -> AlertSummaryResponse.builder()
                .id(a.getId())
                .displayCode(a.getDisplayCode())
                .animalName(a.getAnimal() != null ? a.getAnimal().getName() : "Unknown")
                .animalTag(a.getAnimal() != null ? a.getAnimal().getTagId() : null)
                .species(a.getAnimal() != null ? a.getAnimal().getSpecies() : null)
                .zoneName(a.getZone() != null ? a.getZone().getName() : "Unknown")
                .zoneType(a.getZone() != null ? a.getZone().getType().name() : null)
                .lat(a.getLat())
                .lng(a.getLng())
                .breachTime(a.getBreachTime())
                .threatLevel(a.getThreatLevel())
                .status(a.getStatus())
                .approximateLocation(a.isApproximateLocation())
                .build()).toList();
    }
}
