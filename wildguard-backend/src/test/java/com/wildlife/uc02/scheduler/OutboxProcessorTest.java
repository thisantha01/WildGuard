package com.wildlife.uc02.scheduler;

import com.wildlife.uc02.alert.event.SmsGateway;
import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.repository.AlertRepository;
import com.wildlife.uc02.repository.OutboxMessageRepository;
import com.wildlife.uc02.repository.ParkRepository;
import com.wildlife.uc02.service.api.AlertManager;
import com.wildlife.uc02.service.api.NotificationService;
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
@DisplayName("OutboxProcessor Unit Tests")
class OutboxProcessorTest {

    @Mock private OutboxMessageRepository outboxRepository;
    @Mock private AlertRepository alertRepository;
    @Mock private ParkRepository parkRepository;
    @Mock private AlertManager alertManager;
    @Mock private SmsGateway smsGateway;
    @Mock private NotificationService notificationService;

    private Clock clock;
    private OutboxProcessor processor;

    @BeforeEach
    void setUp() {
        clock = Clock.fixed(Instant.parse("2026-10-08T10:00:00Z"), ZoneOffset.UTC);
        processor = new OutboxProcessor(
                outboxRepository, alertRepository, parkRepository,
                alertManager, smsGateway, notificationService, clock);

        ParkConfig config = ParkConfig.builder()
                .notificationRetryIntervalMin(5)
                .notificationRetryLimitMin(60)
                .build();
        when(parkRepository.findAll()).thenReturn(List.of(Park.builder().config(config).build()));
    }

    @Test
    @DisplayName("should deliver pending outbox message and mark status as SENT")
    void should_deliverPendingMessage_successfully() {
        OutboxMessage message = OutboxMessage.builder()
                .id("msg-1").alertId("alt-1").channel(NotificationChannel.PUSH)
                .recipient("ranger-1").payload("Alert!").attempts(0).status(OutboxStatus.PENDING)
                .nextAttemptAt(Instant.now(clock)).createdAt(Instant.now(clock))
                .build();

        when(outboxRepository.findByStatusAndNextAttemptAtBefore(eq(OutboxStatus.PENDING), any()))
                .thenReturn(List.of(message));

        processor.setPushFailRate(0.0); // 100% success
        processor.processOutbox();

        verify(outboxRepository).save(argThat(m -> m.getStatus() == OutboxStatus.SENT && m.getAttempts() == 1));
    }

    @Test
    @DisplayName("should trigger SMS fallback after first push delivery failure (EF-03)")
    void should_sendSmsFallback_onFirstPushFailure() {
        OutboxMessage message = OutboxMessage.builder()
                .id("msg-2").alertId("alt-1").channel(NotificationChannel.PUSH)
                .recipient("ranger-1").payload("Alert!").attempts(0).status(OutboxStatus.PENDING)
                .nextAttemptAt(Instant.now(clock)).createdAt(Instant.now(clock))
                .build();

        when(outboxRepository.findByStatusAndNextAttemptAtBefore(eq(OutboxStatus.PENDING), any()))
                .thenReturn(List.of(message));

        processor.setPushFailRate(1.0); // 100% simulated failure
        processor.processOutbox();

        verify(smsGateway).send(eq("ranger-1"), contains("[SMS FALLBACK]"));
        verify(outboxRepository).save(argThat(m -> m.getAttempts() == 1 && m.getStatus() == OutboxStatus.PENDING));
    }

    @Test
    @DisplayName("should mark DELIVERY_FAILED and escalate to manager when retry limit exceeded")
    void should_markDeliveryFailed_when_retryLimitExceeded() {
        Instant now = Instant.now(clock);
        // Message created 70 min ago (> 60 min limit), attempts=3
        OutboxMessage message = OutboxMessage.builder()
                .id("msg-3").alertId("alt-1").channel(NotificationChannel.PUSH)
                .recipient("ranger-1").payload("Alert!").attempts(3).status(OutboxStatus.PENDING)
                .nextAttemptAt(now).createdAt(now.minusSeconds(70 * 60L))
                .build();

        when(outboxRepository.findByStatusAndNextAttemptAtBefore(eq(OutboxStatus.PENDING), any()))
                .thenReturn(List.of(message));

        Alert alert = Alert.builder().id("alt-1").displayCode("ALT-0001").status(AlertStatus.NOTIFIED).build();
        when(alertRepository.findById("alt-1")).thenReturn(Optional.of(alert));

        processor.processOutbox();

        verify(outboxRepository).save(argThat(m -> m.getStatus() == OutboxStatus.FAILED));
        verify(alertManager).transitionAlert(eq(alert), eq(AlertStatus.DELIVERY_FAILED), eq("system"), anyString());
        verify(notificationService).notifyManager(eq(alert), contains("CRITICAL"));
    }
}
