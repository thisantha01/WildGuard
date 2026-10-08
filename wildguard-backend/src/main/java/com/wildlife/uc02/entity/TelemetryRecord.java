package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.mapping.DBRef;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

/**
 * A single GPS telemetry packet received from a collar.
 * evaluated=false means the packet has not yet been run through the geofence engine
 * (e.g. it arrived out-of-order or zones were unavailable at ingest time).
 */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_telemetry_records")
@CompoundIndex(name = "collar_timestamp_idx", def = "{'collar.$id': 1, 'timestamp': -1}", unique = true)
public class TelemetryRecord {
    @Id  private String id;
    @DBRef private Collar collar;
    @DBRef private Animal animal;
    private Instant timestamp;
    private double lat;
    private double lng;
    private int batteryPercent;
    @Builder.Default private Instant receivedAt = Instant.now();
    @Builder.Default private boolean evaluated  = false;
}
