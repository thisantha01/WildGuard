package com.wildlife.uc02.dto;
import com.wildlife.uc02.entity.AlertStatus;
import com.wildlife.uc02.entity.ThreatLevel;
import lombok.*;
import java.time.Instant;
@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class AlertSummaryResponse {
    private String id;
    private String displayCode;
    private String animalName;
    private String animalTag;
    private String species;
    private String zoneName;
    private String zoneType;
    private double lat;
    private double lng;
    private Instant breachTime;
    private ThreatLevel threatLevel;
    private AlertStatus status;
    private boolean approximateLocation;
}