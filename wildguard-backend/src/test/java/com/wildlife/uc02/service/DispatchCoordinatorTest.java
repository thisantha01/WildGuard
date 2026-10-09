package com.wildlife.uc02.service;

import com.wildlife.uc02.alert.event.AlertEvent;
import com.wildlife.uc02.alert.event.AlertEventPublisher;
import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.repository.*;
import com.wildlife.uc02.service.api.AlertManager;
import com.wildlife.uc02.service.api.NotificationService;
import com.wildlife.uc02.service.impl.DispatchCoordinatorImpl;
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
@DisplayName("DispatchCoordinator Unit Tests")
class DispatchCoordinatorTest {

    @Mock private RangerStatusRepository rangerStatusRepository;
    @Mock private CloRepository cloRepository;
    @Mock private AlertRepository alertRepository;
    @Mock private AlertAssignmentRepository assignmentRepository;
    @Mock private ParkRepository parkRepository;
    @Mock private NotificationService notificationService;
    @Mock private AlertEventPublisher eventPublisher;
    @Mock private AlertManager alertManager;

    private Clock clock;
    private DispatchCoordinatorImpl coordinator;
    private Park park;

    @BeforeEach
    void setUp() {
        clock = Clock.fixed(Instant.parse("2026-10-08T10:00:00Z"), ZoneOffset.UTC);
        coordinator = new DispatchCoordinatorImpl(
                rangerStatusRepository, cloRepository, alertRepository,
                assignmentRepository, parkRepository, notificationService,
                eventPublisher, alertManager, clock);

        ParkConfig config = ParkConfig.builder()
                .rangerSearchRadiusKm(30)
                .rangerLocationStaleMin(30)
                .build();
        park = Park.builder().id("park-1").config(config).build();
        when(parkRepository.findAll()).thenReturn(List.of(park));
    }

    @Test
    @DisplayName("should dispatch nearest available ranger when multiple rangers are active")
    void should_dispatchNearestAvailableRanger() {
        Instant now = Instant.now(clock);
        RangerStatus nearRanger = RangerStatus.builder()
                .userId("ranger-near").unitCode("R-01").availability(RangerAvailability.AVAILABLE)
                .lastLat(6.3500).lastLng(81.5100).lastLocationAt(now).build(); // ~3 km away

        RangerStatus farRanger = RangerStatus.builder()
                .userId("ranger-far").unitCode("R-02").availability(RangerAvailability.AVAILABLE)
                .lastLat(6.2500).lastLng(81.4000).lastLocationAt(now).build(); // ~18 km away

        when(rangerStatusRepository.findByParkIdAndAvailability("park-1", RangerAvailability.AVAILABLE))
                .thenReturn(List.of(farRanger, nearRanger));
        when(assignmentRepository.findByAlertIdAndOutcomeIn(any(), any())).thenReturn(List.of());

        Alert alert = Alert.builder().id("alt-1").displayCode("ALT-0001").parkId("park-1").lat(6.3700).lng(81.5000).build();

        coordinator.dispatch(alert);

        verify(notificationService).notifyRanger(eq(alert), eq("ranger-near"));
        verify(eventPublisher).publish(argThat(e -> e.getType() == AlertEvent.Type.NOTIFIED && e.getRecipientId().equals("ranger-near")));
        verify(rangerStatusRepository).save(argThat(r -> r.getUserId().equals("ranger-near") && r.getAvailability() == RangerAvailability.BUSY));
    }

    @Test
    @DisplayName("should rank fresh location ranger before stale location ranger even if slightly further")
    void should_rankFreshRangerBeforeStaleRanger() {
        Instant now = Instant.now(clock);
        // Stale ranger (45 min ago, > 30 min stale)
        RangerStatus staleRanger = RangerStatus.builder()
                .userId("ranger-stale").unitCode("R-01").availability(RangerAvailability.AVAILABLE)
                .lastLat(6.3690).lastLng(81.5010).lastLocationAt(now.minusSeconds(45 * 60L)).build();

        // Fresh ranger (2 min ago)
        RangerStatus freshRanger = RangerStatus.builder()
                .userId("ranger-fresh").unitCode("R-02").availability(RangerAvailability.AVAILABLE)
                .lastLat(6.3500).lastLng(81.5100).lastLocationAt(now.minusSeconds(120)).build();

        when(rangerStatusRepository.findByParkIdAndAvailability("park-1", RangerAvailability.AVAILABLE))
                .thenReturn(List.of(staleRanger, freshRanger));
        when(assignmentRepository.findByAlertIdAndOutcomeIn(any(), any())).thenReturn(List.of());

        Alert alert = Alert.builder().id("alt-1").displayCode("ALT-0001").parkId("park-1").lat(6.3700).lng(81.5000).build();

        coordinator.dispatch(alert);

        verify(notificationService).notifyRanger(eq(alert), eq("ranger-fresh"));
    }

    @Test
    @DisplayName("should exclude rangers that previously declined or timed out for this alert")
    void should_excludeDeclinedRangers() {
        Instant now = Instant.now(clock);
        RangerStatus declinedRanger = RangerStatus.builder()
                .userId("ranger-declined").availability(RangerAvailability.AVAILABLE)
                .lastLat(6.3701).lastLng(81.5001).lastLocationAt(now).build();

        RangerStatus alternateRanger = RangerStatus.builder()
                .userId("ranger-alt").availability(RangerAvailability.AVAILABLE)
                .lastLat(6.3500).lastLng(81.5100).lastLocationAt(now).build();

        when(rangerStatusRepository.findByParkIdAndAvailability("park-1", RangerAvailability.AVAILABLE))
                .thenReturn(List.of(declinedRanger, alternateRanger));

        AlertAssignment previousDeclined = AlertAssignment.builder().rangerId("ranger-declined").outcome(AssignmentOutcome.DECLINED).build();
        when(assignmentRepository.findByAlertIdAndOutcomeIn(eq("alt-1"), any())).thenReturn(List.of(previousDeclined));

        Alert alert = Alert.builder().id("alt-1").displayCode("ALT-0001").parkId("park-1").lat(6.3700).lng(81.5000).build();

        coordinator.dispatch(alert);

        verify(notificationService).notifyRanger(eq(alert), eq("ranger-alt"));
    }

    @Test
    @DisplayName("should escalate alert and notify manager when no rangers are available (AF-04)")
    void should_escalateAlert_when_noRangersAvailable() {
        when(rangerStatusRepository.findByParkIdAndAvailability("park-1", RangerAvailability.AVAILABLE))
                .thenReturn(List.of());
        when(assignmentRepository.findByAlertIdAndOutcomeIn(any(), any())).thenReturn(List.of());

        Alert alert = Alert.builder().id("alt-1").displayCode("ALT-0001").parkId("park-1").lat(6.3700).lng(81.5000).build();

        coordinator.dispatch(alert);

        verify(alertManager).transitionAlert(eq(alert), eq(AlertStatus.ESCALATED), eq("system"), anyString());
        verify(notificationService).notifyManager(eq(alert), contains("escalated"));
        verify(eventPublisher).publish(argThat(e -> e.getType() == AlertEvent.Type.ESCALATED));
    }

    @Test
    @DisplayName("should assign CLO when alert occurs in FARMLAND zone")
    void should_assignClo_when_farmlandZone() {
        Instant now = Instant.now(clock);
        RangerStatus ranger = RangerStatus.builder()
                .userId("ranger-1").availability(RangerAvailability.AVAILABLE)
                .lastLat(6.3500).lastLng(81.5100).lastLocationAt(now).build();

        when(rangerStatusRepository.findByParkIdAndAvailability("park-1", RangerAvailability.AVAILABLE))
                .thenReturn(List.of(ranger));
        when(assignmentRepository.findByAlertIdAndOutcomeIn(any(), any())).thenReturn(List.of());

        CommunityLiaisonOfficer clo = CommunityLiaisonOfficer.builder().userId("clo-1").name("Officer Perera").build();
        when(cloRepository.findByParkId("park-1")).thenReturn(List.of(clo));

        GeofenceZone farmland = GeofenceZone.builder().type(ZoneType.FARMLAND).build();
        Alert alert = Alert.builder().id("alt-1").parkId("park-1").zone(farmland).threatLevel(ThreatLevel.MODERATE).lat(6.3700).lng(81.5000).build();

        coordinator.dispatch(alert);

        verify(notificationService).notifyClo(eq(alert), eq("clo-1"));
    }
}
