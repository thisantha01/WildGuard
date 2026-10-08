package com.wildlife.uc02.dto;
import lombok.*;
import java.time.Instant;
@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class TelemetryResponse {
    private String id;
    private String collarCode;
    private Instant timestamp;
    private double latitude;
    private double longitude;
    private int batteryPercent;
    private boolean evaluated;
    private String message;
}