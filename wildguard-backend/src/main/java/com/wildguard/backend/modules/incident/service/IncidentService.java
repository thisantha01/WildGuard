package com.wildguard.backend.modules.incident.service;

import com.wildguard.backend.modules.incident.dto.IncidentBatchSyncRequest;
import com.wildguard.backend.modules.incident.dto.IncidentBatchSyncResponse;
import com.wildguard.backend.modules.incident.dto.IncidentResponse;
import com.wildguard.backend.modules.incident.dto.IncidentSyncRequest;
import com.wildguard.backend.modules.incident.dto.IncidentSyncResponse;

import java.util.List;

public interface IncidentService {

    IncidentSyncResponse syncIncident(IncidentSyncRequest request, String rangerUsername);

    IncidentBatchSyncResponse syncBatch(IncidentBatchSyncRequest batchRequest, String rangerUsername);

    List<IncidentResponse> getRangerIncidentHistory(String rangerUsername);
}
