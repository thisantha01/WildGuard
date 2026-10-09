package com.wildlife.uc02.entity;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Per-park configuration thresholds. Embedded inside {@link Park}.
 * All timing and distance constants live here so business logic stays magic-number-free.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ParkConfig {

    @Builder.Default private int expectedTelemetryIntervalMin = 15;
    @Builder.Default private int transmissionGapMin           = 30;
    @Builder.Default private int groupingRadiusM              = 500;
    @Builder.Default private int rangerSearchRadiusKm         = 30;
    @Builder.Default private int ackTimeoutMin                = 5;
    @Builder.Default private int dispatchTimeoutMin           = 10;
    @Builder.Default private int notificationRetryIntervalMin = 5;
    @Builder.Default private int notificationRetryLimitMin    = 60;
    @Builder.Default private int reEntryConsecutivePackets    = 2;
    @Builder.Default private int safetyBufferM                = 50;
    @Builder.Default private int lowBatteryPercent            = 20;
    @Builder.Default private int rangerLocationStaleMin       = 30;
    @Builder.Default private int averageSpeedKmh              = 40;
}
