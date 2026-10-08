package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

/** Field report submitted by a ranger when on-site (triggers RESOLVED when situationSafe=true). */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_field_reports")
public class FieldReport {
    @Id  private String id;
    private String alertId;
    private String rangerId;
    @Builder.Default private CropDamage cropDamage     = CropDamage.NONE;
    @Builder.Default private InjurySeverity injuries   = InjurySeverity.NONE;
    private boolean situationSafe;
    private String notes;
    private String photoPath;
    @Builder.Default private Instant submittedAt       = Instant.now();
}
