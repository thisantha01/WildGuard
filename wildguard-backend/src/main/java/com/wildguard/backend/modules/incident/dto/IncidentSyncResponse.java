package com.wildguard.backend.modules.incident.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class IncidentSyncResponse {

    private String localIncidentId;
    private String serverIncidentId;
    private String status;
    private String message;
    private boolean duplicateFlag;
    private String duplicateReason;
    private Instant syncedAt;
}
