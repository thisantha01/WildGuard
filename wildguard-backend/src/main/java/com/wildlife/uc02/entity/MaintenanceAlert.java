package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.DBRef;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

/** Maintenance alert for TECHNICIAN / MANAGER about collar health issues. */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_maintenance_alerts")
public class MaintenanceAlert {
    @Id  private String id;
    @DBRef private Collar collar;
    private MaintenanceAlertType type;
    @Builder.Default private Instant createdAt = Instant.now();
    @Builder.Default private boolean resolved  = false;
}
