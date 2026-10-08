package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.mapping.Document;

/** Links an alert to subsequent telemetry records (AF-07 appended telemetry). */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_alert_telemetry_links")
@CompoundIndex(name = "alert_telemetry_idx", def = "{'alertId': 1, 'telemetryId': 1}", unique = true)
public class AlertTelemetryLink {
    @Id  private String id;
    private String alertId;
    private String telemetryId;
}
