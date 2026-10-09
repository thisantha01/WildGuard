package com.wildlife.uc02.alert.event;
import com.wildlife.uc02.entity.Alert;
import lombok.*;
@Getter @AllArgsConstructor
public class AlertEvent {
    public enum Type { CREATED, NOTIFIED, ESCALATED, DELIVERY_FAILED, RESOLVED, FIELD_REPORT }
    private final Type type;
    private final Alert alert;
    private final String recipientId;
}