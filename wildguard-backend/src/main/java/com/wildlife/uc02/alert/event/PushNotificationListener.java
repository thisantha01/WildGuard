package com.wildlife.uc02.alert.event;
import com.wildlife.uc02.entity.NotificationChannel;
import com.wildlife.uc02.service.api.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import java.util.Random;
@Slf4j
@Component
@RequiredArgsConstructor
public class PushNotificationListener implements AlertEventListener {
    private final NotificationService notificationService;
    @Value("${mock.push.fail-rate:0.0}")
    private double failRate;
    @Override
    public boolean supports(AlertEvent.Type type) {
        return type == AlertEvent.Type.NOTIFIED || type == AlertEvent.Type.ESCALATED;
    }
    @Override
    public void onAlertEvent(AlertEvent event) {
        if (new Random().nextDouble() < failRate) {
            log.warn("[MOCK] Push notification simulated failure for alert {}", event.getAlert().getId());
            return;
        }
        String payload = String.format("Alert %s: %s breached zone %s",
            event.getAlert().getDisplayCode(), event.getAlert().getAnimal() != null ? event.getAlert().getAnimal().getName() : "Unknown",
            event.getAlert().getZone() != null ? event.getAlert().getZone().getName() : "Unknown");
        log.info("[MOCK PUSH] To:{} Payload:{}", event.getRecipientId(), payload);
        notificationService.send(event.getAlert().getId(), NotificationChannel.PUSH, event.getRecipientId(), payload);
    }
}