package com.wildguard.backend.modules.incident.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "incidents")
@CompoundIndex(name = "type_timestamp_idx", def = "{'type': 1, 'timestamp': -1}")
public class Incident {

    @Id
    private String id;

    @Indexed
    private String localIncidentId;

    @Indexed
    private String rangerId;

    private String rangerUsername;

    private IncidentType type;

    private IncidentSeverity severity;

    private String description;

    private GeoLocation location;

    private String photoBase64;

    @Indexed
    private Instant timestamp;

    @Builder.Default
    private boolean duplicateFlag = false;

    private String duplicateReason;

    @Builder.Default
    private SyncStatus syncStatus = SyncStatus.SYNCED;

    @Builder.Default
    private Instant syncedAt = Instant.now();

    @CreatedDate
    @Builder.Default
    private Instant createdAt = Instant.now();

    @LastModifiedDate
    @Builder.Default
    private Instant updatedAt = Instant.now();
}
