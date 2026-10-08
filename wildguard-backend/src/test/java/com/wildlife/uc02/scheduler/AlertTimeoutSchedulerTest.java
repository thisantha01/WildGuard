package com.wildlife.uc02.scheduler;

import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.repository.AlertAssignmentRepository;
import com.wildlife.uc02.repository.AlertRepository;
import com.wildlife.uc02.repository.ParkRepository;
import com.wildlife.uc02.repository.RangerStatusRepository;
import com.wildlife.uc02.service.api.AlertManager;
import com.wildlife.uc02.service.api.DispatchCoordinator;
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
@DisplayName("AlertTimeoutScheduler Unit Tests")
class AlertTimeoutSchedulerTest {

    @Mock private AlertRepository alertRepository;
    @Mock private AlertAssignmentRepository assignmentRepository;
    @Mock private RangerStatusRepository rangerStatusRepository;
    @Mock private ParkRepository parkRepository;
    @Mock private DispatchCoordinator dispatchCoordinator;
    @Mock private AlertManager alertManager;

    private Clock clock;
    private AlertTimeoutScheduler scheduler;

    @BeforeEach
    void setUp() {
        clock = Clock.fixed(Instant.parse("2026-10-08T10:00:00Z"), ZoneOffset.UTC);
        scheduler = new AlertTimeoutScheduler(
                alertRepository, assignmentRepository, rangerStatusRepository,
                parkRepository, dispatchCoordinator, alertManager, clock);

        ParkConfig config = ParkConfig.builder()
                .ackTimeoutMin(5)
                .dispatchTimeoutMin(10)
                .build();
        when(parkRepository.findAll()).thenReturn(List.of(Park.builder().config(config).build()));
    }

    @Test
    @DisplayName("should mark assignment TIMED_OUT and reassign when NOTIFIED alert has no ack after 5 min (EF-05)")
    void should_timeoutNotifiedAlert_when_ackTimeoutExceeded() {
        Instant now = Instant.now(clock);
        Alert alert = Alert.builder().id("alt-1").status(AlertStatus.NOTIFIED).assignedRangerId("ranger-1").build();
        when(alertRepository.findByStatus(AlertStatus.NOTIFIED)).thenReturn(List.of(alert));

        AlertAssignment assignment = AlertAssignment.builder()
                .alertId("alt-1").rangerId("ranger-1").outcome(AssignmentOutcome.PENDING)
                .assignedAt(now.minusSeconds(6 * 60L)).build(); // 6 min ago (> 5 min)

        when(assignmentRepository.findByAlertIdAndRangerId("alt-1", "ranger-1"))
                .thenReturn(Optional.of(assignment));

        scheduler.checkTimeouts();

        verify(assignmentRepository).save(argThat(a -> a.getOutcome() == AssignmentOutcome.TIMED_OUT));
        verify(alertManager).transitionAlert(eq(alert), eq(AlertStatus.NOTIFIED), eq("system"), contains("Ack timeout"));
        verify(dispatchCoordinator).dispatch(alert);
    }

    @Test
    @DisplayName("should mark assignment TIMED_OUT and reassign when ACKNOWLEDGED alert has no dispatch after 10 min (EF-05)")
    void should_timeoutAckAlert_when_dispatchTimeoutExceeded() {
        Instant now = Instant.now(clock);
        Alert alert = Alert.builder().id("alt-2").status(AlertStatus.ACKNOWLEDGED)
                .assignedRangerId("ranger-1").acknowledgedAt(now.minusSeconds(12 * 60L)).build(); // 12 min ago (> 10 min)

        when(alertRepository.findByStatus(AlertStatus.ACKNOWLEDGED)).thenReturn(List.of(alert));

        AlertAssignment assignment = AlertAssignment.builder()
                .alertId("alt-2").rangerId("ranger-1").outcome(AssignmentOutcome.ACKNOWLEDGED).build();
        when(assignmentRepository.findByAlertIdAndRangerId("alt-2", "ranger-1"))
                .thenReturn(Optional.of(assignment));

        scheduler.checkTimeouts();

        verify(assignmentRepository).save(argThat(a -> a.getOutcome() == AssignmentOutcome.TIMED_OUT));
        verify(dispatchCoordinator).dispatch(alert);
    }
}
