package com.wildguard.backend.modules.incident.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class IncidentBatchSyncResponse {

    private int totalSubmitted;
    private int totalSynced;
    private int duplicatesFlagged;
    private List<IncidentSyncResponse> syncResults;
}
