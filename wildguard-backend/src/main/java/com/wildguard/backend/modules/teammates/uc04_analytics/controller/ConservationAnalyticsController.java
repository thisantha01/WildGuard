package com.wildguard.backend.modules.teammates.uc04_analytics.controller;

import com.wildguard.backend.modules.teammates.uc04_analytics.ConservationAnalyticsService;
import com.wildguard.backend.modules.teammates.uc04_analytics.dto.AnalyticsDashboardResponse;
import com.wildguard.backend.modules.incident.model.IncidentSeverity;
import com.wildguard.backend.modules.incident.model.IncidentType;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;

/**
 * UC04 - Conservation analytics. Restricted to park managers.
 * (Role restriction is applied here with @PreAuthorize so shared SecurityConfig stays untouched.)
 */
@Slf4j
@RestController
@RequestMapping("/api/analytics")
@RequiredArgsConstructor
@PreAuthorize("hasRole('MANAGER')")
public class ConservationAnalyticsController {

    private final ConservationAnalyticsService analyticsService;

    @GetMapping("/dashboard")
    public ResponseEntity<AnalyticsDashboardResponse> dashboard(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false, defaultValue = "UTC") String tz,
            @RequestParam(required = false) IncidentType type,
            @RequestParam(required = false) IncidentSeverity severity,
            @RequestParam(required = false) String ranger) {
        log.info("Analytics dashboard requested: from={}, to={}, type={}, severity={}, ranger={}",
                from, to, type, severity, ranger);
        return ResponseEntity.ok(analyticsService.getDashboard(from, to, tz, type, severity, ranger));
    }

    @GetMapping(value = "/export", produces = "text/csv")
    public ResponseEntity<byte[]> export(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false, defaultValue = "UTC") String tz,
            @RequestParam(required = false) IncidentType type,
            @RequestParam(required = false) IncidentSeverity severity,
            @RequestParam(required = false) String ranger) {
        String csv = analyticsService.exportCsv(from, to, tz, type, severity, ranger);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"wildguard-incident-report.csv\"")
                .contentType(MediaType.parseMediaType("text/csv; charset=UTF-8"))
                .body(csv.getBytes(StandardCharsets.UTF_8));
    }
}
