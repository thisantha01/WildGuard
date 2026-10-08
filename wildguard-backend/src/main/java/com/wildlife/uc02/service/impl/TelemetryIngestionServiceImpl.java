package com.wildlife.uc02.service.impl;

import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.exception.TelemetryValidationException;
import com.wildlife.uc02.repository.*;
import com.wildlife.uc02.service.api.*;
import com.wildlife.uc02.geometry.BreachResult;
import com.wildlife.uc02.dto.TelemetryRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Component 1: Validates, deduplicates, stores and routes telemetry packets.
 * EF-01: 3 consecutive invalid packets per collar -> INVALID_DATA MaintenanceAlert.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TelemetryIngestionServiceImpl implements TelemetryIngestionService {

    private final CollarRepository collarRepository;
    private final TelemetryRecordRepository telemetryRepository;
    private final MaintenanceAlertRepository maintenanceAlertRepository;
    private final SystemLogRepository systemLogRepository;
    private final GeofenceEngine geofenceEngine;
    private final AlertManager alertManager;
    private final Clock clock;

    /** In-memory counter of consecutive invalid packets per collar code (EF-01). */
    private final Map<String, AtomicInteger> consecutiveInvalidCounts = new ConcurrentHashMap<>();
    private static final int INVALID_STRIKE_LIMIT = 3;

    @Override
    @Transactional
    public TelemetryRecord ingest(TelemetryRequest request) {
        // Validate required fields and ranges
        validatePacket(request);

        Collar collar = collarRepository.findByCode(request.getCollarCode())
                .orElseThrow(() -> new TelemetryValidationException("Unknown collar code: " + request.getCollarCode()));

        // Duplicate detection: same collar + timestamp
        if (telemetryRepository.findByCollarIdAndTimestamp(collar.getId(), request.getTimestamp()).isPresent()) {
            log.debug("Duplicate telemetry ignored: collar={} timestamp={}", collar.getCode(), request.getTimestamp());
            throw new TelemetryValidationException("Duplicate packet: same collar+timestamp already stored");
        }

        // Reset invalid counter on successful validation
        consecutiveInvalidCounts.remove(collar.getCode());

        // Determine if out-of-order (older than last known packet)
        boolean isNewest = collar.getLastPacketAt() == null
                || request.getTimestamp().isAfter(collar.getLastPacketAt());

        // Store the record
        TelemetryRecord record = TelemetryRecord.builder()
                .collar(collar)
                .animal(collar.getAnimal())
                .timestamp(request.getTimestamp())
                .lat(request.getLatitude())
                .lng(request.getLongitude())
                .batteryPercent(request.getBatteryPercent())
                .receivedAt(Instant.now(clock))
                .evaluated(false)
                .build();

        record = telemetryRepository.save(record);

        // Update collar metadata only for the newest packet
        if (isNewest) {
            collar.setLastPacketAt(request.getTimestamp());
            collar.setBatteryPercent(request.getBatteryPercent());
            collarRepository.save(collar);

            // Only evaluate newest packets through geofence engine
            record.setEvaluated(true);
            evaluateGeofence(collar.getAnimal(), record);
            telemetryRepository.save(record);
        }

        log.info("Telemetry ingested: collar={} lat={} lng={} newest={}",
                collar.getCode(), request.getLatitude(), request.getLongitude(), isNewest);
        return record;
    }

    private void evaluateGeofence(Animal animal, TelemetryRecord record) {
        if (animal == null) return;
        try {
            BreachResult result = geofenceEngine.evaluate(animal, record);
            if (result.isInside()) {
                alertManager.handleBreach(animal, result.getZone(), record);
            } else {
                alertManager.handleNonBreach(animal, record);
            }
        } catch (Exception ex) {
            log.error("Geofence evaluation failed for collar {}: {}", record.getCollar().getCode(), ex.getMessage());
            systemLogRepository.save(SystemLog.builder().level("ERROR")
                    .message("Geofence eval failed: " + ex.getMessage()).createdAt(Instant.now(clock)).build());
        }
    }

    private void validatePacket(TelemetryRequest request) {
        if (request.getCollarCode() == null || request.getCollarCode().isBlank()) {
            handleInvalidPacket(null, "Missing collar code");
            throw new TelemetryValidationException("Missing collar code");
        }
        if (request.getTimestamp() == null) {
            handleInvalidPacket(request.getCollarCode(), "Missing timestamp");
            throw new TelemetryValidationException("Missing timestamp");
        }
        if (request.getLatitude() < -90 || request.getLatitude() > 90) {
            handleInvalidPacket(request.getCollarCode(), "Latitude out of range: " + request.getLatitude());
            throw new TelemetryValidationException("Latitude out of range");
        }
        if (request.getLongitude() < -180 || request.getLongitude() > 180) {
            handleInvalidPacket(request.getCollarCode(), "Longitude out of range: " + request.getLongitude());
            throw new TelemetryValidationException("Longitude out of range");
        }
        if (request.getBatteryPercent() < 0 || request.getBatteryPercent() > 100) {
            handleInvalidPacket(request.getCollarCode(), "Battery out of range: " + request.getBatteryPercent());
            throw new TelemetryValidationException("Battery percent out of range");
        }
        if (request.getChecksum() == null || request.getChecksum().isBlank()) {
            handleInvalidPacket(request.getCollarCode(), "Missing checksum");
            throw new TelemetryValidationException("Missing checksum");
        }
    }

    private void handleInvalidPacket(String collarCode, String reason) {
        log.warn("EF-01: Invalid telemetry packet for collar {}: {}", collarCode, reason);
        systemLogRepository.save(SystemLog.builder().level("WARN")
                .message("Invalid packet collar=" + collarCode + " reason=" + reason)
                .createdAt(Instant.now(clock)).build());

        if (collarCode == null) return;

        int count = consecutiveInvalidCounts
                .computeIfAbsent(collarCode, k -> new AtomicInteger(0))
                .incrementAndGet();

        if (count >= INVALID_STRIKE_LIMIT) {
            log.error("EF-01: 3 consecutive invalid packets from collar {}, creating INVALID_DATA maintenance alert", collarCode);
            collarRepository.findByCode(collarCode).ifPresent(collar -> {
                boolean alreadyOpen = maintenanceAlertRepository
                        .findByCollarIdAndTypeAndResolvedFalse(collar.getId(), MaintenanceAlertType.INVALID_DATA)
                        .isPresent();
                if (!alreadyOpen) {
                    maintenanceAlertRepository.save(MaintenanceAlert.builder()
                            .collar(collar).type(MaintenanceAlertType.INVALID_DATA)
                            .createdAt(Instant.now(clock)).resolved(false).build());
                }
            });
            consecutiveInvalidCounts.remove(collarCode);
        }
    }
}