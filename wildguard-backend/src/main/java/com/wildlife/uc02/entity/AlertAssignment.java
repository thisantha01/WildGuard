package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

/**
 * Records each dispatch attempt so that declined or timed-out rangers
 * are excluded from re-assignment (DispatchCoordinator logic).
 */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_alert_assignments")
public class AlertAssignment {
    @Id  private String id;
    private String alertId;
    private String rangerId;
    @Builder.Default private Instant assignedAt = Instant.now();
    @Builder.Default private AssignmentOutcome outcome = AssignmentOutcome.PENDING;
    private String declineReason;
}
