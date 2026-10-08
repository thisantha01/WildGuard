package com.wildlife.uc02.alert.event;
import com.wildlife.uc02.entity.NotificationChannel;
import com.wildlife.uc02.service.api.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
@Slf4j
@Component
@RequiredArgsConstructor
public class SmsNotificationListener implements AlertEventListener {
    private final SmsGateway smsGateway;
    private final NotificationService notificationService;
    @Override
    public boolean supports(AlertEvent.Type type) {
        return type == AlertEvent.Type.ESCALATED || type == AlertEvent.Type.DELIVERY_FAILED;
    }
    @Override
    public void onAlertEvent(AlertEvent event) {
        String message = String.format("WILDLIFE ALERT %s: Animal breach detected. Threat: %s",
            event.getAlert().getDisplayCode(), event.getAlert().getThreatLevel());
        smsGateway.send(event.getRecipientId(), message);
        notificationService.send(event.getAlert().getId(), NotificationChannel.SMS, event.getRecipientId(), message);
    }
}