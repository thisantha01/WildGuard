package com.wildlife.uc02.service.api;
import com.wildlife.uc02.entity.Alert;
import com.wildlife.uc02.entity.NotificationChannel;
/** Sends notifications via the outbox pattern. */
public interface NotificationService {
    void notifyRanger(Alert alert, String rangerId);
    void notifyClo(Alert alert, String cloId);
    void notifyManager(Alert alert, String message);
    void send(String alertId, NotificationChannel channel, String recipient, String payload);
}