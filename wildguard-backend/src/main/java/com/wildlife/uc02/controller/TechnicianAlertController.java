package com.wildlife.uc02.controller;

import com.wildlife.uc02.entity.MaintenanceAlert;
import com.wildlife.uc02.repository.MaintenanceAlertRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Controller for Field Technicians to inspect collar hardware anomalies, low battery, and transmission gaps.
 */
@Slf4j
@RestController
@RequestMapping("/api/maintenance-alerts")
@RequiredArgsConstructor
@Tag(name = "Collar Maintenance", description = "Endpoints for technicians to inspect collar battery and packet anomalies")
public class TechnicianAlertController {

    private final MaintenanceAlertRepository maintenanceAlertRepository;

    @GetMapping
    @PreAuthorize("hasAnyRole('MANAGER', 'RANGER')")
    @Operation(summary = "Get collar maintenance alerts", description = "Lists all hardware maintenance alerts (low battery, transmission gap, invalid packets)")
    public ResponseEntity<List<MaintenanceAlert>> getMaintenanceAlerts() {
        List<MaintenanceAlert> alerts = maintenanceAlertRepository.findAll();
        return ResponseEntity.ok(alerts);
    }
}
