package com.wildlife.uc02.scheduler;

import com.wildlife.uc02.entity.Alert;
import com.wildlife.uc02.entity.AlertAssignment;
import com.wildlife.uc02.entity.AlertStatus;
import com.wildlife.uc02.entity.AssignmentOutcome;
import com.wildlife.uc02.entity.Park;
import com.wildlife.uc02.entity.RangerAvailability;
import com.wildlife.uc02.repository.AlertAssignmentRepository;
import com.wildlife.uc02.repository.AlertRepository;
import com.wildlife.uc02.repository.ParkRepository;
import com.wildlife.uc02.repository.RangerStatusRepository;
import com.wildlife.uc02.service.api.AlertManager;
import com.wildlife.uc02.service.api.DispatchCoordinator;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Instant;
import java.util.List;

/**
 * Component 9: AlertTimeoutScheduler (@Scheduled, EF-05)
 * NOTIFIED with no acknowledgement after ackTimeoutMin -> mark TIMED_OUT, reassign.
 * ACKNOWLEDGED without dispatch confirmation after dispatchTimeoutMin -> mark TIMED_OUT, reassign.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class AlertTimeoutScheduler {

    private final AlertRepository alertRepository;
    private final AlertAssignmentRepository assignmentRepository;
    private final RangerStatusRepository rangerStatusRepository;
    private final ParkRepository parkRepository;
    private final DispatchCoordinator dispatchCoordinator;
    private final AlertManager alertManager;
    private final Clock clock;

    @Scheduled(fixedDelayString = "${uc02.scheduler.alert-timeout-ms:60000}")
    public void checkTimeouts() {
        Park park = parkRepository.findAll().stream().findFirst().orElse(null);
        int ackTimeoutMin = park != null ? park.getConfig().getAckTimeoutMin() : 5;
        int dispatchTimeoutMin = park != null ? park.getConfig().getDispatchTimeoutMin() : 10;

        Instant now = Instant.now(clock);

        checkAckTimeouts(ackTimeoutMin, now);
        checkDispatchTimeouts(dispatchTimeoutMin, now);
    }

    private void checkAckTimeouts(int ackTimeoutMin, Instant now) {
        Instant cutoff = now.minusSeconds(ackTimeoutMin * 60L);
        List<Alert> notifiedAlerts = alertRepository.findByStatus(AlertStatus.NOTIFIED);

        for (Alert alert : notifiedAlerts) {
            if (alert.getAssignedRangerId() == null) continue;

            assignmentRepository.findByAlertIdAndRangerId(alert.getId(), alert.getAssignedRangerId())
                    .ifPresent(assignment -> {
                        if (assignment.getOutcome() == AssignmentOutcome.PENDING
                                && assignment.getAssignedAt() != null
                                && assignment.getAssignedAt().isBefore(cutoff)) {
                            log.warn("EF-05: Ack timeout for alert {} by ranger {}. Reassigning.",
                                    alert.getDisplayCode(), alert.getAssignedRangerId());
                            handleTimeout(alert, assignment, "Ack timeout after " + ackTimeoutMin + " min (EF-05)");
                        }
                    });
        }
    }

    private void checkDispatchTimeouts(int dispatchTimeoutMin, Instant now) {
        Instant cutoff = now.minusSeconds(dispatchTimeoutMin * 60L);
        List<Alert> ackAlerts = alertRepository.findByStatus(AlertStatus.ACKNOWLEDGED);

        for (Alert alert : ackAlerts) {
            if (alert.getAcknowledgedAt() != null && alert.getAcknowledgedAt().isBefore(cutoff)) {
                log.warn("EF-05: Dispatch confirmation timeout for alert {} by ranger {}. Reassigning.",
                        alert.getDisplayCode(), alert.getAssignedRangerId());
                assignmentRepository.findByAlertIdAndRangerId(alert.getId(), alert.getAssignedRangerId())
                        .ifPresent(assignment -> handleTimeout(alert, assignment, "Dispatch timeout after " + dispatchTimeoutMin + " min (EF-05)"));
            }
        }
    }

    private void handleTimeout(Alert alert, AlertAssignment assignment, String note) {
        assignment.setOutcome(AssignmentOutcome.TIMED_OUT);
        assignmentRepository.save(assignment);

        String timedOutRangerId = alert.getAssignedRangerId();
        if (timedOutRangerId != null) {
            rangerStatusRepository.findByUserId(timedOutRangerId).ifPresent(r -> {
                r.setAvailability(RangerAvailability.AVAILABLE);
                rangerStatusRepository.save(r);
            });
        }

        alert.setAssignedRangerId(null);
        alertRepository.save(alert);

        alertManager.transitionAlert(alert, AlertStatus.NOTIFIED, "system", note);
        dispatchCoordinator.dispatch(alert);
    }
}
