package com.wildlife.uc02.controller;

import com.wildlife.uc02.dto.SimulateCollarRequest;
import com.wildlife.uc02.dto.TelemetryRequest;
import com.wildlife.uc02.entity.Animal;
import com.wildlife.uc02.entity.Collar;
import com.wildlife.uc02.exception.AnimalNotFoundException;
import com.wildlife.uc02.exception.CollarNotFoundException;
import com.wildlife.uc02.exception.TelemetryValidationException;
import com.wildlife.uc02.repository.AnimalRepository;
import com.wildlife.uc02.repository.CollarRepository;
import com.wildlife.uc02.scheduler.AlertTimeoutScheduler;
import com.wildlife.uc02.scheduler.CollarHealthMonitor;
import com.wildlife.uc02.scheduler.OutboxProcessor;
import com.wildlife.uc02.service.api.TelemetryIngestionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Clock;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

/**
 * Dev-only simulation controller for interactive live demonstrations.
 * Injects dummy packets according to predefined test scenarios and triggers scheduled jobs on demand.
 */
@Slf4j
@RestController
@RequestMapping("/api/dev")
@RequiredArgsConstructor
@Tag(name = "Dev Collar Simulator", description = "Endpoints for simulating live collar scenarios and triggering background workers for demonstration")
public class DevSimulatorController {

    private final TelemetryIngestionService ingestionService;
    private final AnimalRepository animalRepository;
    private final CollarRepository collarRepository;
    private final CollarHealthMonitor collarHealthMonitor;
    private final AlertTimeoutScheduler alertTimeoutScheduler;
    private final OutboxProcessor outboxProcessor;
    private final Clock clock;

    @PostMapping("/simulate-collar")
    @Operation(summary = "Simulate collar GPS packet scenario",
            description = "Simulates predefined telemetry scenarios: INSIDE_FARMLAND, OUTSIDE_ZONE, MALFORMED, LOW_BATTERY, DUPLICATE, OUT_OF_ORDER, STOP_SENDING")
    public ResponseEntity<Map<String, Object>> simulateCollar(@RequestBody @Valid SimulateCollarRequest request) {
        String animalTag = request.getAnimalTag();
        String scenario = request.getScenario().toUpperCase();

        Animal animal = animalRepository.findByTagId(animalTag)
                .orElseThrow(() -> new AnimalNotFoundException("Animal not found with tag: " + animalTag));

        Collar collar = collarRepository.findByAnimalId(animal.getId())
                .orElseThrow(() -> new CollarNotFoundException("Collar not found for animal tag: " + animalTag));

        Instant now = Instant.now(clock);
        Map<String, Object> result = new HashMap<>();
        result.put("scenario", scenario);
        result.put("animalTag", animalTag);
        result.put("collarCode", collar.getCode());

        switch (scenario) {
            case "INSIDE_FARMLAND" -> {
                // Point inside Yala Sector 04 Farmland polygon (6.3700, 81.5000)
                TelemetryRequest tr = buildPacket(collar.getCode(), 6.3700, 81.5000, 85, now);
                ingestionService.ingest(tr);
                result.put("status", "SUCCESS");
                result.put("message", "Ingested telemetry inside farmland polygon (breach simulated)");
                result.put("location", Map.of("lat", 6.3700, "lng", 81.5000));
            }
            case "OUTSIDE_ZONE" -> {
                // Point outside all geofences in safe jungle (6.3300, 81.4500)
                TelemetryRequest tr = buildPacket(collar.getCode(), 6.3300, 81.4500, 85, now);
                ingestionService.ingest(tr);
                result.put("status", "SUCCESS");
                result.put("message", "Ingested telemetry in safe buffer territory (non-breach)");
                result.put("location", Map.of("lat", 6.3300, "lng", 81.4500));
            }
            case "MALFORMED" -> {
                // EF-01: Invalid latitude (999.0)
                TelemetryRequest tr = buildPacket(collar.getCode(), 999.0, 81.5000, 85, now);
                try {
                    ingestionService.ingest(tr);
                } catch (TelemetryValidationException ex) {
                    result.put("status", "REJECTED_AS_EXPECTED");
                    result.put("error", ex.getMessage());
                }
            }
            case "LOW_BATTERY" -> {
                // AF-01: Battery 12% (threshold <= 20%)
                TelemetryRequest tr = buildPacket(collar.getCode(), 6.3700, 81.5000, 12, now);
                ingestionService.ingest(tr);
                collarHealthMonitor.monitorCollarHealth();
                result.put("status", "SUCCESS");
                result.put("message", "Ingested packet with 12% battery; low battery maintenance alert checked");
            }
            case "DUPLICATE" -> {
                TelemetryRequest tr = buildPacket(collar.getCode(), 6.3700, 81.5000, 85, now);
                ingestionService.ingest(tr);
                // Send exact same packet again
                try {
                    ingestionService.ingest(tr);
                } catch (TelemetryValidationException ex) {
                    result.put("status", "DUPLICATE_REJECTED_AS_EXPECTED");
                    result.put("message", ex.getMessage());
                }
            }
            case "OUT_OF_ORDER" -> {
                // Ingest older packet after newer
                TelemetryRequest current = buildPacket(collar.getCode(), 6.3700, 81.5000, 85, now);
                ingestionService.ingest(current);

                TelemetryRequest past = buildPacket(collar.getCode(), 6.3690, 81.4990, 85, now.minusSeconds(3600));
                ingestionService.ingest(past);
                result.put("status", "SUCCESS");
                result.put("message", "Ingested out-of-order packet (stored unevaluated)");
            }
            case "STOP_SENDING" -> {
                // Set collar lastPacketAt to 45 min ago to simulate transmission gap
                collar.setLastPacketAt(now.minusSeconds(45 * 60L));
                collarRepository.save(collar);
                collarHealthMonitor.monitorCollarHealth();
                result.put("status", "SUCCESS");
                result.put("message", "Collar lastPacketAt shifted to 45 min ago; transmission gap maintenance alert evaluated");
            }
            default -> throw new IllegalArgumentException("Unknown simulation scenario: " + scenario);
        }

        return ResponseEntity.ok(result);
    }

    @PostMapping("/run-schedulers")
    @Operation(summary = "Trigger background schedulers immediately", description = "Executes collar health monitoring, timeout detection, and notification outbox retries immediately")
    public ResponseEntity<Map<String, String>> runSchedulers() {
        log.info("Manually triggering background schedulers via /api/dev/run-schedulers");
        collarHealthMonitor.monitorCollarHealth();
        alertTimeoutScheduler.checkTimeouts();
        outboxProcessor.processOutbox();
        return ResponseEntity.ok(Map.of("message", "Schedulers triggered and executed successfully"));
    }

    private TelemetryRequest buildPacket(String collarCode, double lat, double lng, int battery, Instant timestamp) {
        String checksum = String.format("chk_%s_%d", collarCode, timestamp.getEpochSecond());
        return TelemetryRequest.builder()
                .collarCode(collarCode)
                .latitude(lat)
                .longitude(lng)
                .batteryPercent(battery)
                .timestamp(timestamp)
                .checksum(checksum)
                .build();
    }
}
