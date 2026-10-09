package com.wildlife.uc02.service.impl;

import com.wildlife.uc02.alert.event.SmsGateway;
import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.repository.*;
import com.wildlife.uc02.service.api.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.Instant;

/**
 * Component 6: Writes OutboxMessage rows; Push/Dashboard/SMS are all mocked.
 * AF-09: offline ranger (OFFLINE availability) -> also sends SMS fallback.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationServiceImpl implements NotificationService {
    private final OutboxMessageRepository outboxRepository;
    private final RangerStatusRepository rangerStatusRepository;
    private final SmsGateway smsGateway;
    private final Clock clock;

    @Override
    public void notifyRanger(Alert alert, String rangerId) {
        if (rangerId == null) return;
        String payload = buildPayload(alert);
        send(alert.getId(), NotificationChannel.PUSH, rangerId, payload);
        // AF-09: offline fallback to SMS
        rangerStatusRepository.findByUserId(rangerId).ifPresent(r -> {
            if (r.getAvailability() == RangerAvailability.OFFLINE) {
                log.info("AF-09: Ranger {} is OFFLINE, sending SMS fallback", rangerId);
                smsGateway.send(rangerId, payload);
                send(alert.getId(), NotificationChannel.SMS, rangerId, payload);
            }
        });
    }

    @Override
    public void notifyClo(Alert alert, String cloId) {
        if (cloId == null) return;
        send(alert.getId(), NotificationChannel.PUSH, cloId, buildPayload(alert));
    }

    @Override
    public void notifyManager(Alert alert, String message) {
        send(alert.getId(), NotificationChannel.DASHBOARD, "MANAGER", message);
        log.info("[MOCK MANAGER NOTIFY] {}", message);
    }

    @Override
    public void send(String alertId, NotificationChannel channel, String recipient, String payload) {
        Instant now = Instant.now(clock);
        outboxRepository.save(OutboxMessage.builder()
                .alertId(alertId).channel(channel).recipient(recipient)
                .payload(payload).attempts(0).nextAttemptAt(now).status(OutboxStatus.PENDING).build());
        log.debug("[OUTBOX] queued {} to {} for alert {}", channel, recipient, alertId);
    }

    private String buildPayload(Alert alert) {
        return String.format("ALERT %s: %s in zone %s. Threat: %s",
                alert.getDisplayCode(),
                alert.getAnimal() != null ? alert.getAnimal().getName() : "Unknown",
                alert.getZone() != null ? alert.getZone().getName() : "Unknown",
                alert.getThreatLevel());
    }
}