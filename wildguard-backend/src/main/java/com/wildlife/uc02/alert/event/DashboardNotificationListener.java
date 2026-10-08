package com.wildlife.uc02.alert.event;
import com.wildlife.uc02.entity.NotificationChannel;
import com.wildlife.uc02.service.api.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
@Slf4j
@Component
@RequiredArgsConstructor
public class DashboardNotificationListener implements AlertEventListener {
    private final NotificationService notificationService;
    @Override
    public boolean supports(AlertEvent.Type type) { return true; }
    @Override
    public void onAlertEvent(AlertEvent event) {
        String payload = String.format("[DASHBOARD] Alert %s status: %s",
            event.getAlert().getDisplayCode(), event.getAlert().getStatus());
        log.info("[MOCK DASHBOARD] {}", payload);
        notificationService.send(event.getAlert().getId(), NotificationChannel.DASHBOARD, event.getRecipientId(), payload);
    }
}