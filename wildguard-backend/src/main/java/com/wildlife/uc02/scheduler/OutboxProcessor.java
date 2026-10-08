package com.wildlife.uc02.scheduler;

import com.wildlife.uc02.alert.event.SmsGateway;
import com.wildlife.uc02.entity.Alert;
import com.wildlife.uc02.entity.AlertStatus;
import com.wildlife.uc02.entity.NotificationChannel;
import com.wildlife.uc02.entity.OutboxMessage;
import com.wildlife.uc02.entity.OutboxStatus;
import com.wildlife.uc02.entity.Park;
import com.wildlife.uc02.repository.AlertRepository;
import com.wildlife.uc02.repository.OutboxMessageRepository;
import com.wildlife.uc02.repository.ParkRepository;
import com.wildlife.uc02.service.api.AlertManager;
import com.wildlife.uc02.service.api.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Random;

/**
 * Component 6: Scheduled processor for queued outbox messages (EF-03).
 * Retries delivery every notificationRetryIntervalMin.
 * Uses SMS fallback after first failure.
 * After notificationRetryLimitMin, marks message as FAILED, transitions alert to DELIVERY_FAILED,
 * and escalates to PARK_MANAGER.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class OutboxProcessor {

    private final OutboxMessageRepository outboxRepository;
    private final AlertRepository alertRepository;
    private final ParkRepository parkRepository;
    private final AlertManager alertManager;
    private final SmsGateway smsGateway;
    private final NotificationService notificationService;
    private final Clock clock;

    @Value("${mock.push.fail-rate:0.0}")
    private double pushFailRate;

    private final Random random = new Random();

    @Scheduled(fixedDelayString = "${uc02.scheduler.outbox-processor-ms:30000}")
    public void processOutbox() {
        Park park = parkRepository.findAll().stream().findFirst().orElse(null);
        int retryIntervalMin = park != null ? park.getConfig().getNotificationRetryIntervalMin() : 5;
        int retryLimitMin = park != null ? park.getConfig().getNotificationRetryLimitMin() : 60;

        Instant now = Instant.now(clock);
        List<OutboxMessage> pending = outboxRepository.findByStatusAndNextAttemptAtBefore(OutboxStatus.PENDING, now);

        for (OutboxMessage message : pending) {
            processMessage(message, retryIntervalMin, retryLimitMin, now);
        }
    }

    private void processMessage(OutboxMessage message, int retryIntervalMin, int retryLimitMin, Instant now) {
        Instant expiryThreshold = message.getCreatedAt() != null
                ? message.getCreatedAt().plusSeconds(retryLimitMin * 60L)
                : now;

        // Check if retry limit exceeded
        if (now.isAfter(expiryThreshold) && message.getAttempts() > 0) {
            log.error("EF-03: Notification retry limit ({} min) exceeded for outbox message {}. Marking FAILED.",
                    retryLimitMin, message.getId());
            message.setStatus(OutboxStatus.FAILED);
            outboxRepository.save(message);

            handleDeliveryExhausted(message.getAlertId());
            return;
        }

        // Simulate delivery
        boolean simulatedFailure = message.getChannel() == NotificationChannel.PUSH
                && pushFailRate > 0.0
                && random.nextDouble() < pushFailRate;

        if (simulatedFailure) {
            message.setAttempts(message.getAttempts() + 1);
            message.setNextAttemptAt(now.plusSeconds(retryIntervalMin * 60L));
            log.warn("EF-03: Simulated delivery failure for outbox message {}. Attempt {}",
                    message.getId(), message.getAttempts());

            // SMS fallback after first failure
            if (message.getAttempts() == 1 && message.getRecipient() != null) {
                log.info("EF-03: Sending SMS fallback to {} for alert {}",
                        message.getRecipient(), message.getAlertId());
                smsGateway.send(message.getRecipient(), "[SMS FALLBACK] " + message.getPayload());
            }
            outboxRepository.save(message);
        } else {
            // Success
            message.setAttempts(message.getAttempts() + 1);
            message.setStatus(OutboxStatus.SENT);
            outboxRepository.save(message);
            log.debug("Outbox message {} sent successfully to {} via {}",
                    message.getId(), message.getRecipient(), message.getChannel());
        }
    }

    private void handleDeliveryExhausted(String alertId) {
        if (alertId == null) return;
        alertRepository.findById(alertId).ifPresent(alert -> {
            if (alert.getStatus() == AlertStatus.NOTIFIED || alert.getStatus() == AlertStatus.ACKNOWLEDGED) {
                alertManager.transitionAlert(alert, AlertStatus.DELIVERY_FAILED, "system",
                        "All notification delivery retries exhausted (EF-03)");
                notificationService.notifyManager(alert,
                        "CRITICAL: Delivery failed for alert " + alert.getDisplayCode() + ". Immediate manual intervention required.");
            }
        });
    }

    public void setPushFailRate(double rate) {
        this.pushFailRate = rate;
    }
}
