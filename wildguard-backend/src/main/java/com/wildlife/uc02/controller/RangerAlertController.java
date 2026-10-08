package com.wildlife.uc02.controller;

import com.wildguard.backend.modules.user.model.User;
import com.wildguard.backend.modules.user.repository.UserRepository;
import com.wildlife.uc02.dto.AlertDetailResponse;
import com.wildlife.uc02.dto.AlertSummaryResponse;
import com.wildlife.uc02.dto.DeclineRequest;
import com.wildlife.uc02.dto.FieldReportRequest;
import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.exception.AlertNotFoundException;
import com.wildlife.uc02.exception.Uc02AccessDeniedException;
import com.wildlife.uc02.geometry.HaversineUtil;
import com.wildlife.uc02.repository.*;
import com.wildlife.uc02.service.api.AlertManager;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Controller for Field Rangers to interact with assigned geofence proximity alerts.
 */
@Slf4j
@RestController
@RequestMapping("/api/alerts")
@RequiredArgsConstructor
@Tag(name = "Ranger Alerts", description = "Endpoints for rangers to view and act on assigned alerts")
public class RangerAlertController {

    private final AlertRepository alertRepository;
    private final CollarRepository collarRepository;
    private final SettlementRepository settlementRepository;
    private final RangerStatusRepository rangerStatusRepository;
    private final ParkRepository parkRepository;
    private final UserRepository userRepository;
    private final AlertManager alertManager;

    @GetMapping
    @PreAuthorize("hasAnyRole('RANGER', 'MANAGER')")
    @Operation(summary = "Get alerts (assigned or all)", description = "Lists alerts assigned to authenticated user, or all active alerts")
    public ResponseEntity<List<AlertSummaryResponse>> getMyAlerts(
            @RequestParam(required = false) AlertStatus status,
            @RequestParam(required = false, defaultValue = "false") boolean all,
            Principal principal) {
        String rangerId = resolveRangerId(principal);
        List<Alert> alerts;
        if (all) {
            alerts = (status != null)
                    ? alertRepository.findByStatus(status)
                    : alertRepository.findAll();
        } else {
            alerts = (status != null)
                    ? alertRepository.findByAssignedRangerIdAndStatus(rangerId, status)
                    : alertRepository.findByAssignedRangerId(rangerId);
            // Fallback for testing: if no alerts specifically assigned to this user, show all matching alerts
            if (alerts.isEmpty()) {
                alerts = (status != null)
                        ? alertRepository.findByStatus(status)
                        : alertRepository.findAll();
            }
        }

        List<AlertSummaryResponse> responses = alerts.stream().map(a -> AlertSummaryResponse.builder()
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

        return ResponseEntity.ok(responses);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('RANGER', 'MANAGER')")
    @Operation(summary = "Get alert detail", description = "Fetches comprehensive details for an assigned alert including distance, ETA, and village proximity")
    public ResponseEntity<AlertDetailResponse> getAlertDetail(
            @PathVariable String id,
            Principal principal) {
        String rangerId = resolveRangerId(principal);
        Alert alert = alertRepository.findById(id)
                .orElseThrow(() -> new AlertNotFoundException(id));

        if (!rangerId.equals(alert.getAssignedRangerId())) {
            throw new Uc02AccessDeniedException("Ranger is not assigned to alert " + id);
        }

        // Collar info
        Collar collar = null;
        if (alert.getAnimal() != null) {
            collar = collarRepository.findByAnimalId(alert.getAnimal().getId()).orElse(null);
        }

        // Distance to nearest village/settlement
        String nearestVillage = "None nearby";
        double distanceToVillageM = 0.0;
        List<Settlement> settlements = settlementRepository.findByParkId(alert.getParkId());
        if (!settlements.isEmpty()) {
            Settlement nearest = settlements.stream().min((s1, s2) -> Double.compare(
                    HaversineUtil.distanceMeters(alert.getLat(), alert.getLng(), s1.getLat(), s1.getLng()),
                    HaversineUtil.distanceMeters(alert.getLat(), alert.getLng(), s2.getLat(), s2.getLng())
            )).orElse(null);
            if (nearest != null) {
                nearestVillage = nearest.getName();
                distanceToVillageM = HaversineUtil.distanceMeters(alert.getLat(), alert.getLng(), nearest.getLat(), nearest.getLng());
            }
        }

        // Ranger distance & ETA
        double distanceToRangerKm = 0.0;
        int etaMinutes = 0;
        Park park = parkRepository.findById(alert.getParkId()).orElse(null);
        int avgSpeedKmh = park != null ? park.getConfig().getAverageSpeedKmh() : 40;

        RangerStatus rangerStatus = rangerStatusRepository.findByUserId(rangerId).orElse(null);
        if (rangerStatus != null && rangerStatus.getLastLat() != null && rangerStatus.getLastLng() != null) {
            distanceToRangerKm = HaversineUtil.distanceKm(alert.getLat(), alert.getLng(), rangerStatus.getLastLat(), rangerStatus.getLastLng());
            etaMinutes = (int) Math.round((distanceToRangerKm / avgSpeedKmh) * 60.0);
        }

        // Available actions based on current status
        List<String> actions = new ArrayList<>();
        switch (alert.getStatus()) {
            case NOTIFIED -> { actions.add("ACKNOWLEDGE"); actions.add("DECLINE"); }
            case ACKNOWLEDGED -> actions.add("CONFIRM_DISPATCH");
            case IN_PROGRESS -> { actions.add("ARRIVED"); actions.add("SUBMIT_FIELD_REPORT"); }
            case PENDING_RESOLUTION -> actions.add("SUBMIT_FIELD_REPORT");
            default -> {}
        }

        String safetyInstructions = buildSafetyInstructions(alert.getThreatLevel());

        AlertDetailResponse response = AlertDetailResponse.builder()
                .id(alert.getId())
                .displayCode(alert.getDisplayCode())
                .animalName(alert.getAnimal() != null ? alert.getAnimal().getName() : "Unknown")
                .animalTag(alert.getAnimal() != null ? alert.getAnimal().getTagId() : null)
                .species(alert.getAnimal() != null ? alert.getAnimal().getSpecies() : null)
                .sex(alert.getAnimal() != null ? alert.getAnimal().getSex() : null)
                .collarCode(collar != null ? collar.getCode() : "N/A")
                .collarBattery(collar != null ? collar.getBatteryPercent() : 0)
                .collarStatus(collar != null && collar.getStatus() != null ? collar.getStatus().name() : "UNKNOWN")
                .zoneName(alert.getZone() != null ? alert.getZone().getName() : "Unknown")
                .zoneType(alert.getZone() != null ? alert.getZone().getType().name() : null)
                .lat(alert.getLat())
                .lng(alert.getLng())
                .breachTime(alert.getBreachTime())
                .threatLevel(alert.getThreatLevel())
                .status(alert.getStatus())
                .nearestVillageName(nearestVillage)
                .distanceToVillageM(Math.round(distanceToVillageM * 10.0) / 10.0)
                .distanceToRangerKm(Math.round(distanceToRangerKm * 100.0) / 100.0)
                .etaMinutes(etaMinutes)
                .safetyInstructions(safetyInstructions)
                .approximateLocation(alert.isApproximateLocation())
                .availableActions(actions)
                .acknowledgedAt(alert.getAcknowledgedAt())
                .dispatchConfirmedAt(alert.getDispatchConfirmedAt())
                .build();

        return ResponseEntity.ok(response);
    }

    @PostMapping("/{id}/acknowledge")
    @PreAuthorize("hasRole('RANGER')")
    @Operation(summary = "Acknowledge alert", description = "Ranger acknowledges receipt of the proximity alert")
    public ResponseEntity<Map<String, String>> acknowledge(
            @PathVariable String id,
            Principal principal) {
        String rangerId = resolveRangerId(principal);
        alertManager.acknowledge(id, rangerId);
        return ResponseEntity.ok(Map.of("message", "Alert acknowledged successfully", "status", AlertStatus.ACKNOWLEDGED.name()));
    }

    @PostMapping("/{id}/decline")
    @PreAuthorize("hasRole('RANGER')")
    @Operation(summary = "Decline alert", description = "Ranger declines alert assignment with a reason, triggering automatic reassignment")
    public ResponseEntity<Map<String, String>> decline(
            @PathVariable String id,
            @RequestBody @Valid DeclineRequest request,
            Principal principal) {
        String rangerId = resolveRangerId(principal);
        alertManager.decline(id, rangerId, request.getReason());
        return ResponseEntity.ok(Map.of("message", "Alert declined and scheduled for reassignment"));
    }

    @PostMapping("/{id}/confirm-dispatch")
    @PreAuthorize("hasRole('RANGER')")
    @Operation(summary = "Confirm dispatch", description = "Ranger confirms they are en route to the breach zone")
    public ResponseEntity<Map<String, String>> confirmDispatch(
            @PathVariable String id,
            Principal principal) {
        String rangerId = resolveRangerId(principal);
        alertManager.confirmDispatch(id, rangerId);
        return ResponseEntity.ok(Map.of("message", "Dispatch confirmed. Alert is now IN_PROGRESS", "status", AlertStatus.IN_PROGRESS.name()));
    }

    @PostMapping("/{id}/arrived")
    @PreAuthorize("hasRole('RANGER')")
    @Operation(summary = "Mark arrived", description = "Ranger marks arrival at scene")
    public ResponseEntity<Map<String, String>> arrived(
            @PathVariable String id,
            Principal principal) {
        String rangerId = resolveRangerId(principal);
        alertManager.arrived(id, rangerId);
        return ResponseEntity.ok(Map.of("message", "Arrival recorded"));
    }

    @PostMapping("/{id}/field-report")
    @PreAuthorize("hasRole('RANGER')")
    @Operation(summary = "Submit field report", description = "Ranger submits field report. If situationSafe is true in PENDING_RESOLUTION, marks alert RESOLVED")
    public ResponseEntity<Map<String, String>> submitFieldReport(
            @PathVariable String id,
            @RequestBody @Valid FieldReportRequest request,
            Principal principal) {
        String rangerId = resolveRangerId(principal);
        alertManager.submitFieldReport(id, rangerId, request);
        return ResponseEntity.ok(Map.of("message", "Field report submitted successfully"));
    }

    private String resolveRangerId(Principal principal) {
        if (principal == null) return "ranger_unknown";
        String username = principal.getName();
        return userRepository.findByUsername(username)
                .map(User::getId)
                .orElse(username);
    }

    private String buildSafetyInstructions(ThreatLevel threatLevel) {
        if (threatLevel == null) return "Exercise caution and observe standard wildlife protocols.";
        return switch (threatLevel) {
            case HIGH -> "CRITICAL THREAT: Approach in patrol vehicle with flares and noise deterrents. Do not dismount. Maintain at least 100m distance. Coordinate with local liaison officer immediately.";
            case MODERATE -> "MODERATE THREAT: Monitor elephant herd movement closely. Check community buffer fence integrity. Prepare flash bangs if approaching farmland.";
            case LOW -> "LOW THREAT: Routine observation. Record telemetry trajectory and verify animal stays within designated forest corridor.";
        };
    }
}
