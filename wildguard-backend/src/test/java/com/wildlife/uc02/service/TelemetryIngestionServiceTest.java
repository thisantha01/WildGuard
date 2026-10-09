package com.wildlife.uc02.service;

import com.wildlife.uc02.dto.TelemetryRequest;
import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.exception.TelemetryValidationException;
import com.wildlife.uc02.geometry.BreachResult;
import com.wildlife.uc02.repository.*;
import com.wildlife.uc02.service.api.AlertManager;
import com.wildlife.uc02.service.api.GeofenceEngine;
import com.wildlife.uc02.service.impl.TelemetryIngestionServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("TelemetryIngestionService Unit Tests")
class TelemetryIngestionServiceTest {

    @Mock private CollarRepository collarRepository;
    @Mock private TelemetryRecordRepository telemetryRepository;
    @Mock private MaintenanceAlertRepository maintenanceAlertRepository;
    @Mock private SystemLogRepository systemLogRepository;
    @Mock private GeofenceEngine geofenceEngine;
    @Mock private AlertManager alertManager;

    private Clock clock;
    private TelemetryIngestionServiceImpl ingestionService;

    private Animal testAnimal;
    private Collar testCollar;

    @BeforeEach
    void setUp() {
        clock = Clock.fixed(Instant.parse("2026-10-08T10:00:00Z"), ZoneOffset.UTC);
        ingestionService = new TelemetryIngestionServiceImpl(
                collarRepository, telemetryRepository, maintenanceAlertRepository,
                systemLogRepository, geofenceEngine, alertManager, clock);

        testAnimal = Animal.builder().id("animal-1").name("Rajah").tagId("ELE-024").build();
        testCollar = Collar.builder().id("col-1").code("COL-024").animal(testAnimal).batteryPercent(90).build();
    }

    @Test
    @DisplayName("should successfully ingest valid newest packet and evaluate geofence breach")
    void should_ingestValidPacket_and_evaluateBreach() {
        when(collarRepository.findByCode("COL-024")).thenReturn(Optional.of(testCollar));
        when(telemetryRepository.findByCollarIdAndTimestamp(any(), any())).thenReturn(Optional.empty());
        when(telemetryRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        GeofenceZone zone = GeofenceZone.builder().id("zone-1").name("Farmland").build();
        BreachResult breachResult = BreachResult.builder().inside(true).zone(zone).build();
        when(geofenceEngine.evaluate(eq(testAnimal), any())).thenReturn(breachResult);

        TelemetryRequest request = TelemetryRequest.builder()
                .collarCode("COL-024")
                .latitude(6.3700)
                .longitude(81.5000)
                .batteryPercent(85)
                .timestamp(Instant.now(clock))
                .checksum("valid-chk")
                .build();

        TelemetryRecord record = ingestionService.ingest(request);

        assertThat(record).isNotNull();
        assertThat(record.isEvaluated()).isTrue();
        verify(geofenceEngine).evaluate(eq(testAnimal), any());
        verify(alertManager).handleBreach(eq(testAnimal), eq(zone), any());
        verify(collarRepository).save(argThat(c -> c.getBatteryPercent() == 85));
    }

    @Test
    @DisplayName("should throw TelemetryValidationException when coordinates are out of bounds (EF-01)")
    void should_rejectMalformedCoordinates() {
        TelemetryRequest badLat = TelemetryRequest.builder()
                .collarCode("COL-024")
                .latitude(999.0) // Invalid
                .longitude(81.5000)
                .batteryPercent(85)
                .timestamp(Instant.now(clock))
                .checksum("chk")
                .build();

        assertThatThrownBy(() -> ingestionService.ingest(badLat))
                .isInstanceOf(TelemetryValidationException.class);

        verify(systemLogRepository).save(argThat(l -> l.getMessage().contains("Latitude out of range")));
    }

    @Test
    @DisplayName("should trigger 3-strike INVALID_DATA MaintenanceAlert after three consecutive invalid packets (EF-01)")
    void should_createMaintenanceAlert_onThreeConsecutiveInvalidPackets() {
        when(collarRepository.findByCode("COL-024")).thenReturn(Optional.of(testCollar));

        TelemetryRequest invalid = TelemetryRequest.builder()
                .collarCode("COL-024")
                .latitude(-999.0)
                .longitude(81.5)
                .batteryPercent(50)
                .timestamp(Instant.now(clock))
                .checksum("chk")
                .build();

        // 1st invalid
        try { ingestionService.ingest(invalid); } catch (Exception ignored) {}
        // 2nd invalid
        try { ingestionService.ingest(invalid); } catch (Exception ignored) {}
        // 3rd invalid
        try { ingestionService.ingest(invalid); } catch (Exception ignored) {}

        verify(maintenanceAlertRepository).save(argThat(a ->
                a.getType() == MaintenanceAlertType.INVALID_DATA && a.getCollar().equals(testCollar)));
    }

    @Test
    @DisplayName("should reject duplicate packet with identical collar code and timestamp")
    void should_rejectDuplicatePacket() {
        Instant ts = Instant.now(clock);
        when(collarRepository.findByCode("COL-024")).thenReturn(Optional.of(testCollar));
        when(telemetryRepository.findByCollarIdAndTimestamp("col-1", ts))
                .thenReturn(Optional.of(TelemetryRecord.builder().build()));

        TelemetryRequest duplicate = TelemetryRequest.builder()
                .collarCode("COL-024")
                .latitude(6.37)
                .longitude(81.5)
                .batteryPercent(80)
                .timestamp(ts)
                .checksum("chk")
                .build();

        assertThatThrownBy(() -> ingestionService.ingest(duplicate))
                .isInstanceOf(TelemetryValidationException.class)
                .hasMessageContaining("Duplicate packet");
    }

    @Test
    @DisplayName("should store out-of-order packet with evaluated=false and skip geofence evaluation")
    void should_storeOutOfOrderPacket_unevaluated() {
        Instant current = Instant.now(clock);
        testCollar.setLastPacketAt(current); // Last packet is current

        when(collarRepository.findByCode("COL-024")).thenReturn(Optional.of(testCollar));
        when(telemetryRepository.findByCollarIdAndTimestamp(any(), any())).thenReturn(Optional.empty());
        when(telemetryRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        // Packet with timestamp 1 hour in the past
        TelemetryRequest past = TelemetryRequest.builder()
                .collarCode("COL-024")
                .latitude(6.37)
                .longitude(81.5)
                .batteryPercent(80)
                .timestamp(current.minusSeconds(3600))
                .checksum("chk")
                .build();

        TelemetryRecord record = ingestionService.ingest(past);

        assertThat(record.isEvaluated()).isFalse();
        verifyNoInteractions(geofenceEngine);
    }
}
