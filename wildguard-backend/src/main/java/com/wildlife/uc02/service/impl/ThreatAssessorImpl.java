package com.wildlife.uc02.service.impl;

import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.geometry.HaversineUtil;
import com.wildlife.uc02.repository.*;
import com.wildlife.uc02.service.api.ThreatAssessor;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

/**
 * Component 3: Computes threat level using the Strategy pattern (list of ThreatRules).
 * Pure function: same inputs always produce same output. No side effects.
 * Rules: zone type (VILLAGE/FARMLAND higher), distance to settlement, species, time of day, historical conflict count.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ThreatAssessorImpl implements ThreatAssessor {

    private final SettlementRepository settlementRepository;
    private final AlertRepository alertRepository;
    private final Clock clock;

    private static final double HIGH_THREAT_SETTLEMENT_M  = 500.0;
    private static final double MOD_THREAT_SETTLEMENT_M   = 1500.0;
    private static final double HISTORICAL_SEARCH_RADIUS_KM = 1.0;
    private static final int HISTORICAL_DAYS = 90;
    private static final int NIGHT_START_HOUR = 18;
    private static final int NIGHT_END_HOUR   = 6;

    @Override
    public ThreatLevel assess(Animal animal, GeofenceZone zone, TelemetryRecord telemetry, String parkId) {
        int score = 0;

        // Rule 1: Zone type
        score += zoneTypeScore(zone.getType());

        // Rule 2: Distance to nearest settlement
        score += settlementScore(telemetry.getLat(), telemetry.getLng(), parkId);

        // Rule 3: Species (elephants have inherently higher conflict potential)
        if (animal.getSpecies() != null && animal.getSpecies().toLowerCase().contains("elephant")) {
            score += 1;
        }

        // Rule 4: Time of day (night = higher threat)
        if (isNightTime(Instant.now(clock))) {
            score += 1;
        }

        // Rule 5: Historical conflict count within 1 km in last 90 days
        score += historicalConflictScore(telemetry.getLat(), telemetry.getLng());

        log.debug("Threat assessment for animal {} zone {}: score={}", animal.getName(), zone.getName(), score);

        if (score >= 4) return ThreatLevel.HIGH;
        if (score >= 2) return ThreatLevel.MODERATE;
        return ThreatLevel.LOW;
    }

    private int zoneTypeScore(ZoneType type) {
        return switch (type) {
            case VILLAGE  -> 3;
            case FARMLAND -> 2;
            case ROAD     -> 1;
            case RESTRICTED -> 1;
        };
    }

    private int settlementScore(double lat, double lng, String parkId) {
        List<Settlement> settlements = (parkId != null)
                ? settlementRepository.findByParkId(parkId)
                : settlementRepository.findAll();
        if (settlements == null || settlements.isEmpty()) {
            settlements = settlementRepository.findAll();
        }
        double minDistanceM = settlements.stream()
                .mapToDouble(s -> HaversineUtil.distanceKm(lat, lng, s.getLat(), s.getLng()) * 1000.0)
                .min().orElse(Double.MAX_VALUE);

        if (minDistanceM < HIGH_THREAT_SETTLEMENT_M)  return 2;
        if (minDistanceM < MOD_THREAT_SETTLEMENT_M)   return 1;
        return 0;
    }

    private boolean isNightTime(Instant now) {
        int hour = now.atZone(java.time.ZoneOffset.UTC).getHour();
        return hour >= NIGHT_START_HOUR || hour < NIGHT_END_HOUR;
    }

    private int historicalConflictScore(double lat, double lng) {
        Instant cutoff = Instant.now(clock).minus(HISTORICAL_DAYS, ChronoUnit.DAYS);
        long conflictCount = alertRepository.findAll().stream()
                .filter(a -> a.getBreachTime() != null && a.getBreachTime().isAfter(cutoff))
                .filter(a -> a.getStatus() != AlertStatus.NEW)
                .filter(a -> HaversineUtil.distanceKm(lat, lng, a.getLat(), a.getLng()) <= HISTORICAL_SEARCH_RADIUS_KM)
                .count();
        if (conflictCount >= 5) return 2;
        if (conflictCount >= 2) return 1;
        return 0;
    }
}