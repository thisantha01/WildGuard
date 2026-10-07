package com.wildguard.backend.modules.incident.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.wildguard.backend.common.exception.GlobalExceptionHandler;
import com.wildguard.backend.modules.incident.dto.IncidentBatchSyncRequest;
import com.wildguard.backend.modules.incident.dto.IncidentBatchSyncResponse;
import com.wildguard.backend.modules.incident.dto.IncidentResponse;
import com.wildguard.backend.modules.incident.dto.IncidentSyncRequest;
import com.wildguard.backend.modules.incident.dto.IncidentSyncResponse;
import com.wildguard.backend.modules.incident.model.IncidentSeverity;
import com.wildguard.backend.modules.incident.model.IncidentType;
import com.wildguard.backend.modules.incident.model.SyncStatus;
import com.wildguard.backend.modules.incident.service.IncidentService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.security.Principal;
import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("IncidentController Unit Tests")
class IncidentControllerTest {

    private MockMvc mockMvc;

    private final ObjectMapper objectMapper = new ObjectMapper().registerModule(new JavaTimeModule());

    @Mock
    private IncidentService incidentService;

    @Mock
    private Authentication authentication;

    @InjectMocks
    private IncidentController incidentController;

    private IncidentSyncRequest syncRequest;
    private IncidentSyncResponse syncResponse;
    private Principal principal;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(incidentController)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();

        principal = () -> "ranger_john";

        syncRequest = IncidentSyncRequest.builder()
                .localIncidentId("loc-101")
                .type(IncidentType.SNARE)
                .severity(IncidentSeverity.HIGH)
                .description("Active snare trap recovered")
                .latitude(6.3685)
                .longitude(81.5273)
                .photoBase64("data:image/jpeg;base64,sample")
                .timestamp(Instant.now())
                .build();

        syncResponse = IncidentSyncResponse.builder()
                .localIncidentId("loc-101")
                .serverIncidentId("srv-555")
                .status("SYNCED")
                .message("Incident synchronized successfully.")
                .duplicateFlag(false)
                .syncedAt(Instant.now())
                .build();
    }

    @Test
    @DisplayName("POST /api/incidents/sync - Returns 201 Created and sync response")
    void syncIncident_Success() throws Exception {
        when(incidentService.syncIncident(any(IncidentSyncRequest.class), eq("ranger_john")))
                .thenReturn(syncResponse);

        mockMvc.perform(post("/api/incidents/sync")
                        .principal(principal)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(syncRequest)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.localIncidentId").value("loc-101"))
                .andExpect(jsonPath("$.serverIncidentId").value("srv-555"))
                .andExpect(jsonPath("$.status").value("SYNCED"))
                .andExpect(jsonPath("$.duplicateFlag").value(false));

        verify(incidentService, times(1)).syncIncident(any(IncidentSyncRequest.class), eq("ranger_john"));
    }

    @Test
    @DisplayName("POST /api/incidents/sync/batch - Returns 200 OK and batch response")
    void syncBatch_Success() throws Exception {
        IncidentBatchSyncRequest batchRequest = IncidentBatchSyncRequest.builder()
                .incidents(List.of(syncRequest))
                .build();

        IncidentBatchSyncResponse batchResponse = IncidentBatchSyncResponse.builder()
                .totalSubmitted(1)
                .totalSynced(1)
                .duplicatesFlagged(0)
                .syncResults(List.of(syncResponse))
                .build();

        when(incidentService.syncBatch(any(IncidentBatchSyncRequest.class), eq("ranger_john")))
                .thenReturn(batchResponse);

        mockMvc.perform(post("/api/incidents/sync/batch")
                        .principal(principal)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(batchRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalSubmitted").value(1))
                .andExpect(jsonPath("$.totalSynced").value(1))
                .andExpect(jsonPath("$.duplicatesFlagged").value(0));

        verify(incidentService, times(1)).syncBatch(any(IncidentBatchSyncRequest.class), eq("ranger_john"));
    }

    @Test
    @DisplayName("GET /api/incidents/my-history - Returns 200 OK and list of incidents")
    void getMyIncidentHistory_Success() throws Exception {
        IncidentResponse historyItem = IncidentResponse.builder()
                .id("srv-555")
                .localIncidentId("loc-101")
                .rangerUsername("ranger_john")
                .type(IncidentType.SNARE)
                .severity(IncidentSeverity.HIGH)
                .description("Active snare trap recovered")
                .latitude(6.3685)
                .longitude(81.5273)
                .syncStatus(SyncStatus.SYNCED)
                .timestamp(Instant.now())
                .build();

        when(incidentService.getRangerIncidentHistory("ranger_john"))
                .thenReturn(List.of(historyItem));

        mockMvc.perform(get("/api/incidents/my-history")
                        .principal(principal))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value("srv-555"))
                .andExpect(jsonPath("$[0].localIncidentId").value("loc-101"))
                .andExpect(jsonPath("$[0].type").value("SNARE"));

        verify(incidentService, times(1)).getRangerIncidentHistory("ranger_john");
    }
}
