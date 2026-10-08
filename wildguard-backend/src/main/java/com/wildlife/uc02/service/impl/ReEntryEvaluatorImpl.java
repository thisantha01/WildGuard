package com.wildlife.uc02.service.impl;

import com.wildlife.uc02.entity.Alert;
import com.wildlife.uc02.entity.AlertStatus;
import com.wildlife.uc02.entity.Animal;
import com.wildlife.uc02.entity.Park;
import com.wildlife.uc02.entity.TelemetryRecord;
import com.wildlife.uc02.repository.AlertRepository;
import com.wildlife.uc02.repository.ParkRepository;
import com.wildlife.uc02.service.api.AlertManager;
import com.wildlife.uc02.service.api.ReEntryEvaluator;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Implementation of ReEntryEvaluator.
 * Follows Component 7 specification:
 * - Counts consecutive packets outside zone + safetyBufferM.
 * - Transitions IN_PROGRESS -> PENDING_RESOLUTION upon meeting threshold (AF-05).
 * - AF-08: If animal breaches again while PENDING_RESOLUTION -> reverts to IN_PROGRESS.
 * - Never auto-resolves alerts.
 */
@Slf4j
@Service
public class ReEntryEvaluatorImpl implements ReEntryEvaluator {

    private final AlertRepository alertRepository;
    private final ParkRepository parkRepository;
    private final AlertManager alertManager;
    private final Map<String, Integer> consecutiveOutsideCounts = new ConcurrentHashMap<>();

    public ReEntryEvaluatorImpl(
            AlertRepository alertRepository,
            ParkRepository parkRepository,
            @Lazy AlertManager alertManager) {
        this.alertRepository = alertRepository;
        this.parkRepository = parkRepository;
        this.alertManager = alertManager;
    }

    @Override
    public void evaluateNonBreach(Animal animal, TelemetryRecord telemetry) {
        if (animal == null) return;
        List<Alert> inProgressAlerts = alertRepository.findByAnimalIdAndStatusNotIn(
                animal.getId(), List.of(AlertStatus.RESOLVED, AlertStatus.DELIVERY_FAILED))
                .stream()
                .filter(a -> a.getStatus() == AlertStatus.IN_PROGRESS)
                .toList();

        if (inProgressAlerts.isEmpty()) {
            return;
        }

        int count = consecutiveOutsideCounts.merge(animal.getId(), 1, Integer::sum);
        int threshold = getReEntryThreshold(inProgressAlerts.get(0).getParkId());

        log.debug("ReEntryEvaluator: animal {} count={}, threshold={}", animal.getName(), count, threshold);

        if (count >= threshold) {
            consecutiveOutsideCounts.remove(animal.getId());
            for (Alert alert : inProgressAlerts) {
                log.info("AF-05: Animal {} re-entered safe territory ({} consecutive packets). Alert {} -> PENDING_RESOLUTION",
                        animal.getName(), count, alert.getDisplayCode());
                alertManager.transitionAlert(alert, AlertStatus.PENDING_RESOLUTION, "system",
                        String.format("Animal verified outside zone for %d consecutive packets (AF-05)", count));
            }
        }
    }

    @Override
    public void evaluateBreach(Animal animal, TelemetryRecord telemetry) {
        if (animal == null) return;
        consecutiveOutsideCounts.remove(animal.getId());

        List<Alert> pendingAlerts = alertRepository.findByAnimalIdAndStatusNotIn(
                animal.getId(), List.of(AlertStatus.RESOLVED, AlertStatus.DELIVERY_FAILED))
                .stream()
                .filter(a -> a.getStatus() == AlertStatus.PENDING_RESOLUTION)
                .toList();

        for (Alert alert : pendingAlerts) {
            log.info("AF-08: Animal {} re-breached zone while alert {} in PENDING_RESOLUTION. Reverting to IN_PROGRESS",
                    animal.getName(), alert.getDisplayCode());
            alertManager.transitionAlert(alert, AlertStatus.IN_PROGRESS, "system",
                    "Animal re-entered geofence zone while pending resolution (AF-08)");
        }
    }

    @Override
    public int getConsecutiveOutsideCount(String animalId) {
        return consecutiveOutsideCounts.getOrDefault(animalId, 0);
    }

    @Override
    public void reset(String animalId) {
        consecutiveOutsideCounts.remove(animalId);
    }

    private int getReEntryThreshold(String parkId) {
        if (parkId == null) return 2;
        return parkRepository.findById(parkId)
                .map(Park::getConfig)
                .map(c -> c.getReEntryConsecutivePackets())
                .orElse(2);
    }
}
