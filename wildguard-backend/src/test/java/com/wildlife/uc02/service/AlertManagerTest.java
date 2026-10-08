package com.wildlife.uc02.service;

import com.wildlife.uc02.alert.event.AlertEvent;
import com.wildlife.uc02.alert.event.AlertEventPublisher;
import com.wildlife.uc02.dto.FieldReportRequest;
import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.exception.InvalidAlertTransitionException;
import com.wildlife.uc02.exception.Uc02AccessDeniedException;
import com.wildlife.uc02.repository.*;
import com.wildlife.uc02.service.api.DispatchCoordinator;
import com.wildlife.uc02.service.api.NotificationService;
import com.wildlife.uc02.service.api.ThreatAssessor;
import com.wildlife.uc02.service.impl.AlertManagerImpl;
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

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
@DisplayName("AlertManager Unit Tests")
class AlertManagerTest {

    @Mock private AlertRepository alertRepository;
    @Mock private AlertStatusHistoryRepository historyRepository;
    @Mock private AlertTelemetryLinkRepository telemetryLinkRepository;
    @Mock private AlertAssignmentRepository assignmentRepository;
    @Mock private FieldReportRepository fieldReportRepository;
    @Mock private ParkRepository parkRepository;
    @Mock private RangerStatusRepository rangerStatusRepository;
    @Mock private ThreatAssessor threatAssessor;
    @Mock private DispatchCoordinator dispatchCoordinator;
    @Mock private NotificationService notificationService;
    @Mock private AlertEventPublisher eventPublisher;
    @Mock private SystemLogRepository systemLogRepository;

    private Clock clock;
    private AlertManagerImpl alertManager;
    private Park park;
    private Animal animal;
    private GeofenceZone zone;

    @BeforeEach
    void setUp() {
        clock = Clock.fixed(Instant.parse("2026-10-08T10:00:00Z"), ZoneOffset.UTC);
        alertManager = new AlertManagerImpl(
                alertRepository, historyRepository, telemetryLinkRepository,
                assignmentRepository, fieldReportRepository, parkRepository,
                rangerStatusRepository, threatAssessor, dispatchCoordinator,
                notificationService, eventPublisher, systemLogRepository, clock);

        ParkConfig config = ParkConfig.builder()
                .groupingRadiusM(500)
                .reEntryConsecutivePackets(2)
                .build();
        park = Park.builder().id("park-1").config(config).build();
        when(parkRepository.findAll()).thenReturn(List.of(park));

        animal = Animal.builder().id("animal-1").name("Rajah").build();
        zone = GeofenceZone.builder().id("zone-1").name("Farmland").build();
    }

    @Test
    @DisplayName("should create NEW alert, transition to NOTIFIED, and call dispatch on new breach")
    void should_createAlertAndDispatch_onNewBreach() {
        when(alertRepository.findByAnimalIdAndStatusNotIn(eq("animal-1"), any())).thenReturn(List.of());
        when(threatAssessor.assess(any(), any(), any(), any())).thenReturn(ThreatLevel.MODERATE);
        when(alertRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        TelemetryRecord telemetry = TelemetryRecord.builder().id("tel-1").lat(6.3700).lng(81.5000).timestamp(Instant.now(clock)).build();

        alertManager.handleBreach(animal, zone, telemetry);

        verify(alertRepository, atLeastOnce()).save(argThat(a ->
                a.getStatus() == AlertStatus.NOTIFIED && a.getThreatLevel() == ThreatLevel.MODERATE));
        verify(dispatchCoordinator).dispatch(any());
    }

    @Test
    @DisplayName("should group with existing nearby active alert within groupingRadiusM and raise threat level (AF-03)")
    void should_groupWithNearbyAlert_and_raiseThreat() {
        Alert existingNearby = Alert.builder().id("lead-1").displayCode("ALT-0001")
                .status(AlertStatus.NOTIFIED).lat(6.3710).lng(81.5010).build();

        when(alertRepository.findByAnimalIdAndStatusNotIn(eq("animal-1"), any())).thenReturn(List.of());
        when(alertRepository.findByStatusIn(any())).thenReturn(List.of(existingNearby));
        when(threatAssessor.assess(any(), any(), any(), any())).thenReturn(ThreatLevel.LOW);
        when(alertRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        TelemetryRecord telemetry = TelemetryRecord.builder().id("tel-1").lat(6.3700).lng(81.5000).timestamp(Instant.now(clock)).build();

        alertManager.handleBreach(animal, zone, telemetry);

        verify(alertRepository, atLeastOnce()).save(argThat(a ->
                "lead-1".equals(a.getGroupAlertId()) && a.getThreatLevel() == ThreatLevel.MODERATE));
    }

    @Test
    @DisplayName("should append telemetry to existing active alert and raise threat level if higher (AF-07)")
    void should_appendTelemetry_and_raiseThreatIfHigher() {
        Alert activeAlert = Alert.builder().id("alt-1").displayCode("ALT-0001")
                .animal(animal).zone(zone).status(AlertStatus.NOTIFIED).threatLevel(ThreatLevel.LOW)
                .lat(6.3700).lng(81.5000).assignedRangerId("ranger-1").build();

        when(alertRepository.findByAnimalIdAndStatusNotIn(eq("animal-1"), any())).thenReturn(List.of(activeAlert));
        when(telemetryLinkRepository.findByAlertId("alt-1")).thenReturn(List.of());
        when(threatAssessor.assess(any(), any(), any(), any())).thenReturn(ThreatLevel.HIGH);

        TelemetryRecord newTelemetry = TelemetryRecord.builder().id("tel-2").lat(6.3720).lng(81.5020).build();

        alertManager.handleBreach(animal, zone, newTelemetry);

        verify(telemetryLinkRepository).save(argThat(l -> l.getAlertId().equals("alt-1") && l.getTelemetryId().equals("tel-2")));
        verify(alertRepository).save(argThat(a -> a.getThreatLevel() == ThreatLevel.HIGH && a.getLat() == 6.3720));
        verify(notificationService).notifyRanger(eq(activeAlert), eq("ranger-1"));
    }

    @Test
    @DisplayName("should revert PENDING_RESOLUTION back to IN_PROGRESS when animal re-breaches zone (AF-08)")
    void should_revertToInProgress_when_animalReBreaches() {
        Alert pendingAlert = Alert.builder().id("alt-1").animal(animal).zone(zone)
                .threatLevel(ThreatLevel.MODERATE)
                .status(AlertStatus.PENDING_RESOLUTION).build();
        when(alertRepository.findByAnimalIdAndStatusNotIn(eq("animal-1"), any())).thenReturn(List.of(pendingAlert));
        when(threatAssessor.assess(any(), any(), any(), any())).thenReturn(ThreatLevel.MODERATE);

        TelemetryRecord telemetry = TelemetryRecord.builder().id("tel-1").lat(6.3700).lng(81.5000).build();

        alertManager.handleBreach(animal, zone, telemetry);

        verify(alertRepository, atLeastOnce()).save(argThat(a -> a.getStatus() == AlertStatus.IN_PROGRESS));
    }

    @Test
    @DisplayName("should successfully execute ranger workflow: ACKNOWLEDGE -> CONFIRM_DISPATCH -> ARRIVED")
    void should_executeRangerWorkflow() {
        Alert alert = Alert.builder().id("alt-1").status(AlertStatus.NOTIFIED).assignedRangerId("ranger-1").build();
        when(alertRepository.findById("alt-1")).thenReturn(Optional.of(alert));

        alertManager.acknowledge("alt-1", "ranger-1");
        assertThat(alert.getStatus()).isEqualTo(AlertStatus.ACKNOWLEDGED);

        alertManager.confirmDispatch("alt-1", "ranger-1");
        assertThat(alert.getStatus()).isEqualTo(AlertStatus.IN_PROGRESS);

        alertManager.arrived("alt-1", "ranger-1");
        verify(historyRepository, atLeast(2)).save(any());
    }

    @Test
    @DisplayName("should reject action when unassigned ranger attempts to acknowledge alert")
    void should_rejectUnassignedRangerAction() {
        Alert alert = Alert.builder().id("alt-1").status(AlertStatus.NOTIFIED).assignedRangerId("ranger-1").build();
        when(alertRepository.findById("alt-1")).thenReturn(Optional.of(alert));

        assertThatThrownBy(() -> alertManager.acknowledge("alt-1", "intruder-ranger"))
                .isInstanceOf(Uc02AccessDeniedException.class);
    }

    @Test
    @DisplayName("should resolve alert ONLY when field report has situationSafe=true while in PENDING_RESOLUTION")
    void should_resolveAlert_onlyWhenSituationSafe() {
        Alert alert = Alert.builder().id("alt-1").status(AlertStatus.PENDING_RESOLUTION).assignedRangerId("ranger-1").build();
        when(alertRepository.findById("alt-1")).thenReturn(Optional.of(alert));

        FieldReportRequest request = FieldReportRequest.builder()
                .cropDamage(CropDamage.NONE)
                .injuries(InjurySeverity.NONE)
                .situationSafe(true)
                .notes("Elephant guided back to jungle")
                .build();

        alertManager.submitFieldReport("alt-1", "ranger-1", request);

        assertThat(alert.getStatus()).isEqualTo(AlertStatus.RESOLVED);
        verify(eventPublisher).publish(argThat(e -> e.getType() == AlertEvent.Type.RESOLVED));
    }

    @Test
    @DisplayName("should throw InvalidAlertTransitionException if field report is submitted in IN_PROGRESS state")
    void should_throwIfFieldReportSubmittedBeforePendingResolution() {
        Alert alert = Alert.builder().id("alt-1").status(AlertStatus.IN_PROGRESS).assignedRangerId("ranger-1").build();
        when(alertRepository.findById("alt-1")).thenReturn(Optional.of(alert));

        FieldReportRequest request = FieldReportRequest.builder().situationSafe(true).build();

        assertThatThrownBy(() -> alertManager.submitFieldReport("alt-1", "ranger-1", request))
                .isInstanceOf(InvalidAlertTransitionException.class);
    }
}
