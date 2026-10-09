package com.wildlife.uc02.service;

import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.repository.AlertRepository;
import com.wildlife.uc02.repository.SettlementRepository;
import com.wildlife.uc02.service.impl.ThreatAssessorImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@DisplayName("ThreatAssessor Unit Tests")
class ThreatAssessorTest {

    @Mock private SettlementRepository settlementRepository;
    @Mock private AlertRepository alertRepository;

    private Clock dayClock;
    private Clock nightClock;

    @BeforeEach
    void setUp() {
        // Daytime: 12:00 UTC
        dayClock = Clock.fixed(Instant.parse("2026-10-08T12:00:00Z"), ZoneOffset.UTC);
        // Nighttime: 21:00 UTC (9:00 PM)
        nightClock = Clock.fixed(Instant.parse("2026-10-08T21:00:00Z"), ZoneOffset.UTC);
    }

    @Test
    @DisplayName("should compute HIGH threat when animal breaches VILLAGE zone close to settlement at night")
    void should_computeHighThreat_when_villageZoneNearSettlementAtNight() {
        ThreatAssessorImpl assessor = new ThreatAssessorImpl(settlementRepository, alertRepository, nightClock);

        Settlement settlement = Settlement.builder().name("Ihatikulama").lat(6.3750).lng(81.5050).build();
        when(settlementRepository.findByParkId(anyString())).thenReturn(List.of(settlement));

        Animal elephant = Animal.builder().name("Rajah").species("Sri Lankan Elephant").build();
        GeofenceZone zone = GeofenceZone.builder().name("Village Buffer").type(ZoneType.VILLAGE).build();
        TelemetryRecord telemetry = TelemetryRecord.builder().lat(6.3740).lng(81.5040).timestamp(Instant.now()).build();

        ThreatLevel level = assessor.assess(elephant, zone, telemetry, "park-1");
        assertThat(level).isEqualTo(ThreatLevel.HIGH);
    }

    @Test
    @DisplayName("should compute LOW threat in remote ROAD zone during daytime far from settlements")
    void should_computeLowThreat_when_daytimeFarFromSettlement() {
        ThreatAssessorImpl assessor = new ThreatAssessorImpl(settlementRepository, alertRepository, dayClock);

        Settlement farSettlement = Settlement.builder().name("Distant").lat(7.0000).lng(82.0000).build();
        when(settlementRepository.findByParkId(anyString())).thenReturn(List.of(farSettlement));

        Animal deer = Animal.builder().name("Chital").species("Spotted Deer").build();
        GeofenceZone zone = GeofenceZone.builder().name("Park Road").type(ZoneType.ROAD).build();
        TelemetryRecord telemetry = TelemetryRecord.builder().lat(6.3000).lng(81.4000).timestamp(Instant.now()).build();

        ThreatLevel level = assessor.assess(deer, zone, telemetry, "park-1");
        assertThat(level).isEqualTo(ThreatLevel.LOW);
    }

    @Test
    @DisplayName("should boost score when multiple historical conflicts occurred within 1km in last 90 days")
    void should_boostScore_when_historicalConflictsExist() {
        ThreatAssessorImpl assessor = new ThreatAssessorImpl(settlementRepository, alertRepository, dayClock);

        when(settlementRepository.findByParkId(anyString())).thenReturn(List.of());

        // 3 historic alerts nearby
        Instant now = Instant.now(dayClock);
        Alert h1 = Alert.builder().status(AlertStatus.RESOLVED).lat(6.3705).lng(81.5005).breachTime(now.minusSeconds(86400)).build();
        Alert h2 = Alert.builder().status(AlertStatus.RESOLVED).lat(6.3702).lng(81.5002).breachTime(now.minusSeconds(86400 * 2)).build();
        Alert h3 = Alert.builder().status(AlertStatus.RESOLVED).lat(6.3708).lng(81.5008).breachTime(now.minusSeconds(86400 * 3)).build();
        when(alertRepository.findAll()).thenReturn(List.of(h1, h2, h3));

        Animal elephant = Animal.builder().name("Rajah").species("Sri Lankan Elephant").build();
        GeofenceZone zone = GeofenceZone.builder().name("Farmland").type(ZoneType.FARMLAND).build();
        TelemetryRecord telemetry = TelemetryRecord.builder().lat(6.3700).lng(81.5000).timestamp(now).build();

        ThreatLevel level = assessor.assess(elephant, zone, telemetry, "park-1");
        assertThat(level).isIn(ThreatLevel.MODERATE, ThreatLevel.HIGH);
    }
}
