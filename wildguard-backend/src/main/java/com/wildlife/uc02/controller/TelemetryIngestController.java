package com.wildlife.uc02.controller;

import com.wildlife.uc02.dto.TelemetryRequest;
import com.wildlife.uc02.dto.TelemetryResponse;
import com.wildlife.uc02.entity.TelemetryRecord;
import com.wildlife.uc02.service.api.TelemetryIngestionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * Public IoT ingestion endpoint for elephant telemetry collars.
 * Authenticated via header X-Collar-Key rather than user JWT.
 */
@Slf4j
@RestController
@RequestMapping("/api/telemetry")
@RequiredArgsConstructor
@Tag(name = "IoT Collar Telemetry Ingest", description = "Public hardware gateway endpoint for IoT collars submitting GPS telemetry")
public class TelemetryIngestController {

    private final TelemetryIngestionService telemetryIngestionService;

    @PostMapping
    @Operation(summary = "Ingest collar GPS packet", description = "Validates telemetry payload, checks checksum and battery, stores packet, and triggers geofence evaluation")
    public ResponseEntity<TelemetryResponse> ingest(
            @RequestHeader(value = "X-Collar-Key", required = false)
            @Parameter(description = "Hardware collar API key") String collarKey,
            @RequestBody @Valid TelemetryRequest request) {

        log.debug("Received telemetry packet from collar {}: lat={}, lng={}, batt={}%",
                request.getCollarCode(), request.getLatitude(), request.getLongitude(), request.getBatteryPercent());

        TelemetryRecord record = telemetryIngestionService.ingest(request);

        TelemetryResponse response = TelemetryResponse.builder()
                .id(record.getId())
                .collarCode(request.getCollarCode())
                .timestamp(record.getTimestamp())
                .latitude(record.getLat())
                .longitude(record.getLng())
                .batteryPercent(record.getBatteryPercent())
                .evaluated(record.isEvaluated())
                .message("Telemetry packet ingested successfully")
                .build();

        return ResponseEntity.ok(response);
    }
}
