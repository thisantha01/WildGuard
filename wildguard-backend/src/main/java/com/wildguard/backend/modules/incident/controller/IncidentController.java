package com.wildguard.backend.modules.incident.controller;

import com.wildguard.backend.modules.incident.dto.IncidentBatchSyncRequest;
import com.wildguard.backend.modules.incident.dto.IncidentBatchSyncResponse;
import com.wildguard.backend.modules.incident.dto.IncidentResponse;
import com.wildguard.backend.modules.incident.dto.IncidentSyncRequest;
import com.wildguard.backend.modules.incident.dto.IncidentSyncResponse;
import com.wildguard.backend.modules.incident.service.IncidentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.security.Principal;
import java.util.List;

@Slf4j
@RestController
@RequestMapping("/api/incidents")
@RequiredArgsConstructor
public class IncidentController {

    private final IncidentService incidentService;

    @PostMapping("/sync")
    @PreAuthorize("hasRole('RANGER')")
    public ResponseEntity<IncidentSyncResponse> syncIncident(
            @Valid @RequestBody IncidentSyncRequest request,
            Principal principal) {
        log.info("Received incident sync request for Local ID: {} from Ranger: {}",
                request.getLocalIncidentId(), principal.getName());
        IncidentSyncResponse response = incidentService.syncIncident(request, principal.getName());
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PostMapping("/sync/batch")
    @PreAuthorize("hasRole('RANGER')")
    public ResponseEntity<IncidentBatchSyncResponse> syncBatch(
            @Valid @RequestBody IncidentBatchSyncRequest batchRequest,
            Principal principal) {
        log.info("Received batch sync request ({} items) from Ranger: {}",
                batchRequest.getIncidents().size(), principal.getName());
        IncidentBatchSyncResponse response = incidentService.syncBatch(batchRequest, principal.getName());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/my-history")
    @PreAuthorize("hasRole('RANGER')")
    public ResponseEntity<List<IncidentResponse>> getMyIncidentHistory(Principal principal) {
        log.info("Ranger '{}' requested their logged incident history", principal.getName());
        List<IncidentResponse> history = incidentService.getRangerIncidentHistory(principal.getName());
        return ResponseEntity.ok(history);
    }
}
