package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.Version;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.DBRef;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

/**
 * The central alert entity for UC02.
 * displayCode uses the format ALT-0001.
 * groupAlertId links alerts that were grouped by proximity (AF-03).
 * approximateLocation=true when EF-06 bounding-box fallback was used.
 * @Version enables optimistic locking against concurrent ranger actions.
 */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_alerts")
public class Alert {
    @Id  private String id;
    @Indexed(unique = true) private String displayCode;
    @DBRef private Animal animal;
    @DBRef private GeofenceZone zone;
    private String parkId;
    @Builder.Default private AlertStatus status      = AlertStatus.NEW;
    @Builder.Default private ThreatLevel threatLevel = ThreatLevel.LOW;
    private double lat;
    private double lng;
    private Instant breachTime;
    private Instant acknowledgedAt;
    private Instant dispatchConfirmedAt;
    private Instant resolvedAt;
    private String assignedRangerId;
    private String assignedCloId;
    private String groupAlertId;
    @Builder.Default private boolean approximateLocation = false;
    @Version private Long version;
}
