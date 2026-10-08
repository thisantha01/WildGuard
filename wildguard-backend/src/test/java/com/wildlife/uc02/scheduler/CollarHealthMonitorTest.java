package com.wildlife.uc02.scheduler;

import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.repository.CollarRepository;
import com.wildlife.uc02.repository.MaintenanceAlertRepository;
import com.wildlife.uc02.repository.ParkRepository;
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
import java.util.Optional;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("CollarHealthMonitor Unit Tests")
class CollarHealthMonitorTest {

    @Mock private CollarRepository collarRepository;
    @Mock private MaintenanceAlertRepository maintenanceAlertRepository;
    @Mock private ParkRepository parkRepository;

    private Clock clock;
    private CollarHealthMonitor monitor;
    private Park park;

    @BeforeEach
    void setUp() {
        clock = Clock.fixed(Instant.parse("2026-10-08T10:00:00Z"), ZoneOffset.UTC);
        monitor = new CollarHealthMonitor(collarRepository, maintenanceAlertRepository, parkRepository, clock);

        ParkConfig config = ParkConfig.builder()
                .lowBatteryPercent(20)
                .transmissionGapMin(30)
                .build();
        park = Park.builder().config(config).build();
        when(parkRepository.findAll()).thenReturn(List.of(park));
    }

    @Test
    @DisplayName("should create LOW_BATTERY MaintenanceAlert when battery <= 20% and no open alert exists (AF-01)")
    void should_createLowBatteryAlert() {
        Collar lowBatCollar = Collar.builder()
                .id("c-1").code("COL-001").batteryPercent(15).status(CollarStatus.ACTIVE).build();
        when(collarRepository.findAll()).thenReturn(List.of(lowBatCollar));
        when(maintenanceAlertRepository.findByCollarIdAndTypeAndResolvedFalse("c-1", MaintenanceAlertType.LOW_BATTERY))
                .thenReturn(Optional.empty());

        monitor.monitorCollarHealth();

        verify(maintenanceAlertRepository).save(argThat(a ->
                a.getType() == MaintenanceAlertType.LOW_BATTERY && a.getCollar().equals(lowBatCollar)));
        verify(collarRepository).save(argThat(c -> c.getStatus() == CollarStatus.LOW_BATTERY));
    }

    @Test
    @DisplayName("should not duplicate LOW_BATTERY alert if one is already open")
    void should_notDuplicateLowBatteryAlert() {
        Collar lowBatCollar = Collar.builder().id("c-1").code("COL-001").batteryPercent(15).build();
        when(collarRepository.findAll()).thenReturn(List.of(lowBatCollar));
        when(maintenanceAlertRepository.findByCollarIdAndTypeAndResolvedFalse("c-1", MaintenanceAlertType.LOW_BATTERY))
                .thenReturn(Optional.of(MaintenanceAlert.builder().build()));

        monitor.monitorCollarHealth();

        verify(maintenanceAlertRepository, never()).save(any());
    }

    @Test
    @DisplayName("should create TRANSMISSION_GAP MaintenanceAlert when lastPacketAt is older than 30 min (AF-02)")
    void should_createTransmissionGapAlert() {
        Instant now = Instant.now(clock);
        Collar silentCollar = Collar.builder()
                .id("c-2").code("COL-002").batteryPercent(80)
                .lastPacketAt(now.minusSeconds(45 * 60L)) // 45 min stale
                .status(CollarStatus.ACTIVE).build();

        when(collarRepository.findAll()).thenReturn(List.of(silentCollar));
        when(maintenanceAlertRepository.findByCollarIdAndTypeAndResolvedFalse("c-2", MaintenanceAlertType.TRANSMISSION_GAP))
                .thenReturn(Optional.empty());

        monitor.monitorCollarHealth();

        verify(maintenanceAlertRepository).save(argThat(a ->
                a.getType() == MaintenanceAlertType.TRANSMISSION_GAP && a.getCollar().equals(silentCollar)));
        verify(collarRepository).save(argThat(c -> c.getStatus() == CollarStatus.TRANSMISSION_GAP));
    }
}
