package com.wildlife.uc02.dto;
import com.wildlife.uc02.entity.AlertStatus;
import com.wildlife.uc02.entity.ThreatLevel;
import lombok.*;
import java.time.Instant;
import java.util.List;
@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class AlertDetailResponse {
    private String id;
    private String displayCode;
    private String animalName;
    private String animalTag;
    private String species;
    private String sex;
    private String collarCode;
    private int collarBattery;
    private String collarStatus;
    private String zoneName;
    private String zoneType;
    private double lat;
    private double lng;
    private Instant breachTime;
    private ThreatLevel threatLevel;
    private AlertStatus status;
    private String nearestVillageName;
    private double distanceToVillageM;
    private double distanceToRangerKm;
    private int etaMinutes;
    private String safetyInstructions;
    private boolean approximateLocation;
    private List<String> availableActions;
    private Instant acknowledgedAt;
    private Instant dispatchConfirmedAt;
}