package com.wildguard.backend.modules.incident.dto;

import com.wildguard.backend.modules.incident.model.IncidentSeverity;
import com.wildguard.backend.modules.incident.model.IncidentType;
import com.wildguard.backend.modules.incident.model.SyncStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class IncidentResponse {

    private String id;
    private String localIncidentId;
    private String rangerId;
    private String rangerUsername;
    private IncidentType type;
    private IncidentSeverity severity;
    private String description;
    private Double latitude;
    private Double longitude;
    private String photoBase64;
    private Instant timestamp;
    private boolean duplicateFlag;
    private String duplicateReason;
    private SyncStatus syncStatus;
    private Instant syncedAt;
}
