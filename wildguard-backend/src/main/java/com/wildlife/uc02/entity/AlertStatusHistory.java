package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

/** Audit trail for every alert state transition. */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_alert_status_history")
public class AlertStatusHistory {
    @Id  private String id;
    private String alertId;
    private AlertStatus fromStatus;
    private AlertStatus toStatus;
    @Builder.Default private Instant changedAt = Instant.now();
    private String changedBy;
    private String note;
}
