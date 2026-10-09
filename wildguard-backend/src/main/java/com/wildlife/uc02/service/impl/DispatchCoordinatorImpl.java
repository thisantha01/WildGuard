package com.wildlife.uc02.service.impl;

import com.wildlife.uc02.alert.event.*;
import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.geometry.HaversineUtil;
import com.wildlife.uc02.repository.*;
import com.wildlife.uc02.service.api.DispatchCoordinator;
import com.wildlife.uc02.service.api.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Component 5: Selects nearest AVAILABLE ranger within rangerSearchRadiusKm.
 * AF-04: None found -> ESCALATED + notify PARK_MANAGER.
 * CLO selected for FARMLAND/VILLAGE or HIGH threat.
 */
import com.wildlife.uc02.service.api.AlertManager;
import org.springframework.context.annotation.Lazy;

@Slf4j
@Service
public class DispatchCoordinatorImpl implements DispatchCoordinator {

    private final RangerStatusRepository rangerStatusRepository;
    private final CloRepository cloRepository;
    private final AlertRepository alertRepository;
    private final AlertAssignmentRepository assignmentRepository;
    private final ParkRepository parkRepository;
    private final NotificationService notificationService;
    private final AlertEventPublisher eventPublisher;
    private final AlertManager alertManager;
    private final Clock clock;

    public DispatchCoordinatorImpl(
            RangerStatusRepository rangerStatusRepository,
            CloRepository cloRepository,
            AlertRepository alertRepository,
            AlertAssignmentRepository assignmentRepository,
            ParkRepository parkRepository,
            NotificationService notificationService,
            AlertEventPublisher eventPublisher,
            @Lazy AlertManager alertManager,
            Clock clock) {
        this.rangerStatusRepository = rangerStatusRepository;
        this.cloRepository = cloRepository;
        this.alertRepository = alertRepository;
        this.assignmentRepository = assignmentRepository;
        this.parkRepository = parkRepository;
        this.notificationService = notificationService;
        this.eventPublisher = eventPublisher;
        this.alertManager = alertManager;
        this.clock = clock;
    }

    @Override
    @Transactional
    public void dispatch(Alert alert) {
        Park park = parkRepository.findAll().stream().findFirst().orElse(null);
        int searchRadiusKm = park != null ? park.getConfig().getRangerSearchRadiusKm() : 30;
        int staleMin = park != null ? park.getConfig().getRangerLocationStaleMin() : 30;

        // Collect already-declined/timed-out rangers for this alert
        Set<String> excludedRangerIds = assignmentRepository.findByAlertIdAndOutcomeIn(
                alert.getId(), List.of(AssignmentOutcome.DECLINED, AssignmentOutcome.TIMED_OUT))
                .stream().map(AlertAssignment::getRangerId).collect(Collectors.toSet());

        List<RangerStatus> candidates = rangerStatusRepository
                .findByParkIdAndAvailability(alert.getParkId(), RangerAvailability.AVAILABLE);

        Instant staleThreshold = Instant.now(clock).minusSeconds(staleMin * 60L);

        // Separate fresh and stale rangers
        List<RangerStatus> fresh = candidates.stream()
                .filter(r -> !excludedRangerIds.contains(r.getUserId()))
                .filter(r -> r.getLastLat() != null && r.getLastLng() != null)
                .filter(r -> r.getLastLocationAt() != null && r.getLastLocationAt().isAfter(staleThreshold))
                .sorted(Comparator.comparingDouble(r ->
                        HaversineUtil.distanceKm(alert.getLat(), alert.getLng(), r.getLastLat(), r.getLastLng())))
                .collect(Collectors.toList());

        List<RangerStatus> stale = candidates.stream()
                .filter(r -> !excludedRangerIds.contains(r.getUserId()))
                .filter(r -> r.getLastLat() == null || r.getLastLng() == null
                        || r.getLastLocationAt() == null || !r.getLastLocationAt().isAfter(staleThreshold))
                .collect(Collectors.toList());

        // Try fresh rangers first, then stale (ranked last per spec)
        List<RangerStatus> ordered = new ArrayList<>(fresh);
        ordered.addAll(stale);

        Optional<RangerStatus> selected = ordered.stream()
                .filter(r -> r.getLastLat() == null || r.getLastLng() == null ||
                        HaversineUtil.distanceKm(alert.getLat(), alert.getLng(), r.getLastLat(), r.getLastLng()) <= searchRadiusKm)
                .findFirst();

        if (selected.isEmpty()) {
            // AF-04: No ranger available -> ESCALATE
            log.warn("AF-04: No available ranger found for alert {}. Escalating.", alert.getDisplayCode());
            alertManager.transitionAlert(alert, AlertStatus.ESCALATED, "system", "No ranger available (AF-04)");
            notificationService.notifyManager(alert, "Alert " + alert.getDisplayCode() + " escalated: no available ranger");
            eventPublisher.publish(new AlertEvent(AlertEvent.Type.ESCALATED, alert, "MANAGER"));
            return;
        }

        RangerStatus ranger = selected.get();
        alert.setAssignedRangerId(ranger.getUserId());
        alertRepository.save(alert);

        // Record assignment
        assignmentRepository.save(AlertAssignment.builder()
                .alertId(alert.getId()).rangerId(ranger.getUserId())
                .assignedAt(Instant.now(clock)).outcome(AssignmentOutcome.PENDING).build());

        // Mark ranger as BUSY
        ranger.setAvailability(RangerAvailability.BUSY);
        rangerStatusRepository.save(ranger);

        // Notify ranger
        notificationService.notifyRanger(alert, ranger.getUserId());
        eventPublisher.publish(new AlertEvent(AlertEvent.Type.NOTIFIED, alert, ranger.getUserId()));

        // CLO selection for FARMLAND/VILLAGE or HIGH threat
        if (needsClo(alert)) {
            cloRepository.findByParkId(alert.getParkId()).stream().findFirst().ifPresent(clo -> {
                alert.setAssignedCloId(clo.getUserId());
                alertRepository.save(alert);
                notificationService.notifyClo(alert, clo.getUserId());
                log.info("CLO {} assigned to alert {}", clo.getName(), alert.getDisplayCode());
            });
        }

        log.info("Alert {} dispatched to ranger {} (distance={}km)",
                alert.getDisplayCode(), ranger.getUnitCode(),
                ranger.getLastLat() != null ? String.format("%.1f",
                        HaversineUtil.distanceKm(alert.getLat(), alert.getLng(), ranger.getLastLat(), ranger.getLastLng())) : "unknown");
    }

    private boolean needsClo(Alert alert) {
        if (alert.getThreatLevel() == ThreatLevel.HIGH) return true;
        if (alert.getZone() == null) return false;
        return alert.getZone().getType() == ZoneType.FARMLAND || alert.getZone().getType() == ZoneType.VILLAGE;
    }
}