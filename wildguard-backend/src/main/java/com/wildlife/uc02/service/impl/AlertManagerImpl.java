package com.wildlife.uc02.service.impl;

import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.entity.AlertStatus;
import com.wildlife.uc02.alert.state.*;
import com.wildlife.uc02.alert.event.*;
import com.wildlife.uc02.dto.FieldReportRequest;
import com.wildlife.uc02.exception.*;
import com.wildlife.uc02.geometry.HaversineUtil;
import com.wildlife.uc02.repository.*;
import com.wildlife.uc02.service.api.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.*;

/**
 * Component 4: AlertManager orchestrates the entire alert lifecycle.
 * Handles breach detection, grouping (AF-03), append telemetry (AF-07),
 * re-entry evaluation (AF-08), and all ranger actions.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AlertManagerImpl implements AlertManager {

    private final AlertRepository alertRepository;
    private final AlertStatusHistoryRepository historyRepository;
    private final AlertTelemetryLinkRepository telemetryLinkRepository;
    private final AlertAssignmentRepository assignmentRepository;
    private final FieldReportRepository fieldReportRepository;
    private final ParkRepository parkRepository;
    private final RangerStatusRepository rangerStatusRepository;
    private final ThreatAssessor threatAssessor;
    private final DispatchCoordinator dispatchCoordinator;
    private final NotificationService notificationService;
    private final AlertEventPublisher eventPublisher;
    private final SystemLogRepository systemLogRepository;
    private final Clock clock;

    /** Consecutive out-of-zone packets per animal for re-entry detection. */
    private final Map<String, Integer> consecutiveOutOfZone = new HashMap<>();

    private static final List<AlertStatus> TERMINAL_STATUSES = List.of(AlertStatus.RESOLVED, AlertStatus.DELIVERY_FAILED);
    private static final String DISPLAY_CODE_PREFIX = "ALT-";

    @Override
    @Transactional
    public void handleBreach(Animal animal, GeofenceZone zone, TelemetryRecord telemetry) {
        consecutiveOutOfZone.remove(animal.getId());

        // Check for existing active alert for this animal+zone
        List<AlertStatus> excluded = new ArrayList<>(TERMINAL_STATUSES);
        List<Alert> existing = alertRepository.findByAnimalIdAndStatusNotIn(animal.getId(), excluded);

        // AF-08: Check if animal re-breaches while in PENDING_RESOLUTION
        Optional<Alert> pendingAlert = existing.stream()
                .filter(a -> a.getStatus() == AlertStatus.PENDING_RESOLUTION)
                .findFirst();
        if (pendingAlert.isPresent()) {
            log.info("AF-08: Animal {} re-breached while PENDING_RESOLUTION, reverting to IN_PROGRESS", animal.getName());
            transitionAlert(pendingAlert.get(), AlertStatus.IN_PROGRESS, "system", "Animal re-entered zone (AF-08)");
            appendTelemetry(pendingAlert.get(), telemetry);
            return;
        }

        Optional<Alert> activeAlert = existing.stream()
                .filter(a -> a.getZone() != null && a.getZone().getId().equals(zone.getId()))
                .findFirst();

        if (activeAlert.isPresent()) {
            // AF-07: Append telemetry, update location, raise threat only if higher
            appendTelemetry(activeAlert.get(), telemetry);
        } else {
            // New breach: assess threat, create alert, group, dispatch
            createNewAlert(animal, zone, telemetry);
        }
    }

    @Override
    @Transactional
    public void handleNonBreach(Animal animal, TelemetryRecord telemetry) {
        List<Alert> active = alertRepository.findByAnimalIdAndStatusNotIn(animal.getId(), TERMINAL_STATUSES);
        for (Alert alert : active) {
            if (alert.getStatus() == AlertStatus.IN_PROGRESS) {
                handleReEntry(animal, alert, telemetry);
            }
        }
    }

    @Override
    @Transactional
    public void acknowledge(String alertId, String rangerId) {
        Alert alert = getAlertOrThrow(alertId);
        verifyRangerAssignment(alert, rangerId);
        transitionAlert(alert, AlertStatus.ACKNOWLEDGED, rangerId, "Ranger acknowledged");
        alert.setAcknowledgedAt(Instant.now(clock));
        alertRepository.save(alert);
        updateAssignmentOutcome(alertId, rangerId, AssignmentOutcome.ACKNOWLEDGED);
    }

    @Override
    @Transactional
    public void decline(String alertId, String rangerId, String reason) {
        Alert alert = getAlertOrThrow(alertId);
        verifyRangerAssignment(alert, rangerId);
        updateAssignmentOutcome(alertId, rangerId, AssignmentOutcome.DECLINED);
        // Mark ranger as available again
        rangerStatusRepository.findByUserId(rangerId).ifPresent(rs -> {
            rs.setAvailability(RangerAvailability.AVAILABLE);
            rangerStatusRepository.save(rs);
        });
        // Re-dispatch
        alert.setAssignedRangerId(null);
        alertRepository.save(alert);
        transitionAlert(alert, AlertStatus.NOTIFIED, "system", "Ranger declined: " + reason);
        dispatchCoordinator.dispatch(alert);
    }

    @Override
    @Transactional
    public void confirmDispatch(String alertId, String rangerId) {
        Alert alert = getAlertOrThrow(alertId);
        verifyRangerAssignment(alert, rangerId);
        transitionAlert(alert, AlertStatus.IN_PROGRESS, rangerId, "Ranger confirmed dispatch");
        alert.setDispatchConfirmedAt(Instant.now(clock));
        alertRepository.save(alert);
    }

    @Override
    @Transactional
    public void arrived(String alertId, String rangerId) {
        Alert alert = getAlertOrThrow(alertId);
        verifyRangerAssignment(alert, rangerId);
        historyRepository.save(AlertStatusHistory.builder()
                .alertId(alertId).fromStatus(alert.getStatus()).toStatus(alert.getStatus())
                .changedAt(Instant.now(clock)).changedBy(rangerId).note("Ranger arrived on scene").build());
    }

    @Override
    @Transactional
    public void submitFieldReport(String alertId, String rangerId, FieldReportRequest request) {
        Alert alert = getAlertOrThrow(alertId);
        verifyRangerAssignment(alert, rangerId);
        if (alert.getStatus() != AlertStatus.PENDING_RESOLUTION) {
            throw new InvalidAlertTransitionException("Field report only accepted in PENDING_RESOLUTION status");
        }

        FieldReport report = FieldReport.builder()
                .alertId(alertId).rangerId(rangerId)
                .cropDamage(request.getCropDamage())
                .injuries(request.getInjuries())
                .situationSafe(request.getSituationSafe())
                .notes(request.getNotes())
                .submittedAt(Instant.now(clock))
                .build();
        fieldReportRepository.save(report);

        if (Boolean.TRUE.equals(request.getSituationSafe())) {
            transitionAlert(alert, AlertStatus.RESOLVED, rangerId, "Situation confirmed safe - field report submitted");
            alert.setResolvedAt(Instant.now(clock));
            alertRepository.save(alert);
            eventPublisher.publish(new AlertEvent(AlertEvent.Type.RESOLVED, alert, alert.getAssignedRangerId()));
        }
    }

    // ---- Private helpers ----

    private void createNewAlert(Animal animal, GeofenceZone zone, TelemetryRecord telemetry) {
        String parkId = findParkId();
        ThreatLevel threat = threatAssessor.assess(animal, zone, telemetry, parkId);

        Alert alert = Alert.builder()
                .displayCode(generateDisplayCode())
                .animal(animal)
                .zone(zone)
                .parkId(parkId)
                .status(AlertStatus.NEW)
                .threatLevel(threat)
                .lat(telemetry.getLat())
                .lng(telemetry.getLng())
                .breachTime(telemetry.getTimestamp())
                .build();

        // AF-03: grouping - check for other active alerts within groupingRadiusM
        int groupingRadiusM = getGroupingRadius(parkId);
        double groupingRadiusKm = groupingRadiusM / 1000.0;
        List<Alert> nearbyAlerts = alertRepository.findByStatusIn(
                List.of(AlertStatus.NEW, AlertStatus.NOTIFIED, AlertStatus.ACKNOWLEDGED, AlertStatus.IN_PROGRESS));
        Optional<Alert> groupLeader = nearbyAlerts.stream()
                .filter(a -> HaversineUtil.distanceKm(telemetry.getLat(), telemetry.getLng(), a.getLat(), a.getLng()) <= groupingRadiusKm)
                .findFirst();

        if (groupLeader.isPresent()) {
            String groupId = groupLeader.get().getGroupAlertId() != null
                    ? groupLeader.get().getGroupAlertId() : groupLeader.get().getId();
            alert.setGroupAlertId(groupId);
            // Raise threat by 1 level for group
            alert.setThreatLevel(raiseThreatLevel(threat));
            log.info("AF-03: Alert grouped with {} (groupId={})", groupLeader.get().getDisplayCode(), groupId);
        }

        alert = alertRepository.save(alert);
        recordHistory(alert, null, AlertStatus.NEW, "system", "Alert created");

        // Transition: NEW -> NOTIFIED
        transitionAlert(alert, AlertStatus.NOTIFIED, "system", "Dispatching to ranger");
        dispatchCoordinator.dispatch(alert);
    }

    private void appendTelemetry(Alert alert, TelemetryRecord telemetry) {
        // AF-07: Link new telemetry to existing alert
        boolean alreadyLinked = telemetryLinkRepository.findByAlertId(alert.getId()).stream()
                .anyMatch(l -> l.getTelemetryId().equals(telemetry.getId()));
        if (!alreadyLinked) {
            telemetryLinkRepository.save(AlertTelemetryLink.builder()
                    .alertId(alert.getId()).telemetryId(telemetry.getId()).build());
        }
        // Update location
        alert.setLat(telemetry.getLat());
        alert.setLng(telemetry.getLng());
        // Raise threat only if higher
        String parkId = findParkId();
        ThreatLevel newThreat = threatAssessor.assess(alert.getAnimal(), alert.getZone(), telemetry, parkId);
        if (newThreat != null && alert.getThreatLevel() != null && newThreat.ordinal() > alert.getThreatLevel().ordinal()) {
            alert.setThreatLevel(newThreat);
            alertRepository.save(alert);
            // Re-notify
            notificationService.notifyRanger(alert, alert.getAssignedRangerId());
            log.info("AF-07: Threat level raised to {} for alert {}", newThreat, alert.getDisplayCode());
        } else {
            alertRepository.save(alert);
        }
    }

    private void handleReEntry(Animal animal, Alert alert, TelemetryRecord telemetry) {
        int count = consecutiveOutOfZone.merge(animal.getId(), 1, Integer::sum);
        Park park = parkRepository.findAll().stream().findFirst().orElse(null);
        int threshold = park != null ? park.getConfig().getReEntryConsecutivePackets() : 2;
        int safetyBuffer = park != null ? park.getConfig().getSafetyBufferM() : 50;

        log.debug("Re-entry check for animal {}: {} consecutive out-of-zone packets (threshold={})",
                animal.getName(), count, threshold);

        if (count >= threshold) {
            consecutiveOutOfZone.remove(animal.getId());
            transitionAlert(alert, AlertStatus.PENDING_RESOLUTION, "system",
                    String.format("Animal has been outside zone for %d consecutive packets", count));
            log.info("AF-05: Alert {} moved to PENDING_RESOLUTION for animal {}", alert.getDisplayCode(), animal.getName());
        }
    }

    @Override
    public void transitionAlert(Alert alert, AlertStatus toStatus, String changedBy, String note) {
        AlertStatus fromStatus = alert.getStatus();
        AlertState state = AlertStateFactory.of(fromStatus);
        AlertState nextState = switch (toStatus) {
            case NOTIFIED           -> state.notified(alert);
            case ACKNOWLEDGED       -> state.acknowledged(alert);
            case IN_PROGRESS        -> state.inProgress(alert);
            case PENDING_RESOLUTION -> state.pendingResolution(alert);
            case RESOLVED           -> state.resolved(alert);
            case ESCALATED          -> state.escalated(alert);
            case DELIVERY_FAILED    -> state.deliveryFailed(alert);
            default -> throw new InvalidAlertTransitionException("Unsupported target status: " + toStatus);
        };
        alert.setStatus(toStatus);
        alertRepository.save(alert);
        recordHistory(alert, fromStatus, toStatus, changedBy, note);
        log.info("Alert {} transitioned: {} -> {}", alert.getDisplayCode(), fromStatus, toStatus);
    }

    private void recordHistory(Alert alert, AlertStatus from, AlertStatus to, String changedBy, String note) {
        historyRepository.save(AlertStatusHistory.builder()
                .alertId(alert.getId()).fromStatus(from).toStatus(to)
                .changedAt(Instant.now(clock)).changedBy(changedBy).note(note).build());
    }

    private Alert getAlertOrThrow(String alertId) {
        return alertRepository.findById(alertId)
                .orElseThrow(() -> new AlertNotFoundException(alertId));
    }

    private void verifyRangerAssignment(Alert alert, String rangerId) {
        if (!rangerId.equals(alert.getAssignedRangerId())) {
            throw new Uc02AccessDeniedException("Ranger " + rangerId + " is not assigned to alert " + alert.getId());
        }
    }

    private void updateAssignmentOutcome(String alertId, String rangerId, AssignmentOutcome outcome) {
        assignmentRepository.findByAlertIdAndRangerId(alertId, rangerId).ifPresent(a -> {
            a.setOutcome(outcome);
            assignmentRepository.save(a);
        });
    }

    private String generateDisplayCode() {
        long count = alertRepository.countByDisplayCodeStartingWith(DISPLAY_CODE_PREFIX);
        return String.format("%s%04d", DISPLAY_CODE_PREFIX, count + 1);
    }

    private String findParkId() {
        return parkRepository.findAll().stream().findFirst().map(Park::getId).orElse(null);
    }

    private int getGroupingRadius(String parkId) {
        if (parkId == null) return 500;
        return parkRepository.findById(parkId).map(p -> p.getConfig().getGroupingRadiusM()).orElse(500);
    }

    private ThreatLevel raiseThreatLevel(ThreatLevel level) {
        return switch (level) {
            case LOW      -> ThreatLevel.MODERATE;
            case MODERATE -> ThreatLevel.HIGH;
            case HIGH     -> ThreatLevel.HIGH;
        };
    }
}