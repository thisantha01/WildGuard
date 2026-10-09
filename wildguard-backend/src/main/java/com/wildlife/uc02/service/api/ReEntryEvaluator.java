package com.wildlife.uc02.service.api;

import com.wildlife.uc02.entity.Animal;
import com.wildlife.uc02.entity.TelemetryRecord;

/**
 * Component 7: Evaluates re-entry conditions for animals with active alerts.
 * Tracks consecutive packets outside zone + safety buffer to transition to PENDING_RESOLUTION.
 * Handles AF-08 re-breach transitions. Never auto-resolves alerts.
 */
public interface ReEntryEvaluator {
    void evaluateNonBreach(Animal animal, TelemetryRecord telemetry);
    void evaluateBreach(Animal animal, TelemetryRecord telemetry);
    int getConsecutiveOutsideCount(String animalId);
    void reset(String animalId);
}
