package com.wildguard.backend.modules.incident.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class IncidentBatchSyncRequest {

    @NotEmpty(message = "Incidents batch list cannot be empty")
    @Valid
    private List<IncidentSyncRequest> incidents;
}
