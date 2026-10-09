package com.wildlife.uc02.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.wildlife.uc02.dto.SyncActionRequest;
import com.wildlife.uc02.dto.SyncActionResult;
import com.wildlife.uc02.dto.SyncBatchRequest;
import com.wildlife.uc02.dto.SyncBatchResponse;
import com.wildlife.uc02.entity.ProcessedClientAction;
import com.wildlife.uc02.repository.ProcessedClientActionRepository;
import com.wildlife.uc02.service.api.AlertManager;
import com.wildlife.uc02.service.api.RangerLocationService;
import com.wildlife.uc02.service.impl.SyncServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("SyncService Unit Tests")
class SyncServiceTest {

    @Mock private ProcessedClientActionRepository processedRepo;
    @Mock private AlertManager alertManager;
    @Mock private RangerLocationService locationService;

    private SyncServiceImpl syncService;
    private Clock clock;

    @BeforeEach
    void setUp() {
        clock = Clock.fixed(Instant.parse("2026-10-08T10:00:00Z"), ZoneOffset.UTC);
        ObjectMapper mapper = new ObjectMapper();
        mapper.registerModule(new JavaTimeModule());
        syncService = new SyncServiceImpl(processedRepo, alertManager, locationService, mapper, clock);
    }

    @Test
    @DisplayName("should apply valid action and record processedClientAction")
    void should_applyValidAction() {
        when(processedRepo.existsByClientActionId("act-1")).thenReturn(false);

        SyncActionRequest action = SyncActionRequest.builder()
                .clientActionId("act-1")
                .type("ACKNOWLEDGE")
                .alertId("alt-100")
                .occurredAt(Instant.now(clock))
                .build();

        SyncBatchResponse response = syncService.process(new SyncBatchRequest(List.of(action)), "ranger-1");

        assertThat(response.getResults()).hasSize(1);
        SyncActionResult res = response.getResults().get(0);
        assertThat(res.getStatus()).isEqualTo("APPLIED");
        verify(alertManager).acknowledge(eq("alt-100"), eq("ranger-1"));
        verify(processedRepo).save(any(ProcessedClientAction.class));
    }

    @Test
    @DisplayName("should be idempotent and mark DUPLICATE when clientActionId was already processed")
    void should_skipDuplicateActions() {
        when(processedRepo.existsByClientActionId("act-dup")).thenReturn(true);

        SyncActionRequest action = SyncActionRequest.builder()
                .clientActionId("act-dup")
                .type("CONFIRM_DISPATCH")
                .alertId("alt-100")
                .occurredAt(Instant.now(clock))
                .build();

        SyncBatchResponse response = syncService.process(new SyncBatchRequest(List.of(action)), "ranger-1");

        assertThat(response.getResults()).hasSize(1);
        assertThat(response.getResults().get(0).getStatus()).isEqualTo("DUPLICATE");
        verifyNoInteractions(alertManager);
    }

    @Test
    @DisplayName("should mark REJECTED and continue batch when an individual action fails")
    void should_markRejectedWithoutFailingBatch() {
        when(processedRepo.existsByClientActionId("act-fail")).thenReturn(false);
        doThrow(new RuntimeException("Alert already resolved")).when(alertManager).acknowledge(any(), any());

        SyncActionRequest action = SyncActionRequest.builder()
                .clientActionId("act-fail")
                .type("ACKNOWLEDGE")
                .alertId("alt-old")
                .occurredAt(Instant.now(clock))
                .build();

        SyncBatchResponse response = syncService.process(new SyncBatchRequest(List.of(action)), "ranger-1");

        assertThat(response.getResults()).hasSize(1);
        assertThat(response.getResults().get(0).getStatus()).isEqualTo("REJECTED");
        assertThat(response.getResults().get(0).getReason()).contains("Alert already resolved");
    }
}
