package com.wildlife.uc02.service.impl;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.wildlife.uc02.dto.*;
import com.wildlife.uc02.entity.ProcessedClientAction;
import com.wildlife.uc02.repository.ProcessedClientActionRepository;
import com.wildlife.uc02.service.api.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Component 10: Idempotent offline sync. Applies actions in occurredAt order.
 * Skips already-processed clientActionIds. Returns per-action status.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SyncServiceImpl implements SyncService {
    private final ProcessedClientActionRepository processedRepo;
    private final AlertManager alertManager;
    private final RangerLocationService rangerLocationService;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    @Override
    public SyncBatchResponse process(SyncBatchRequest request, String rangerId) {
        List<SyncActionResult> results = new ArrayList<>();
        int applied = 0, duplicates = 0, rejected = 0;

        List<SyncActionRequest> ordered = request.getActions().stream()
                .sorted(Comparator.comparing(SyncActionRequest::getOccurredAt))
                .collect(Collectors.toList());

        for (SyncActionRequest action : ordered) {
            SyncActionResult result = processAction(action, rangerId);
            results.add(result);
            switch (result.getStatus()) {
                case "APPLIED"    -> applied++;
                case "DUPLICATE"  -> duplicates++;
                default           -> rejected++;
            }
        }

        return SyncBatchResponse.builder().results(results)
                .applied(applied).duplicates(duplicates).rejected(rejected).build();
    }

    @Transactional
    protected SyncActionResult processAction(SyncActionRequest action, String rangerId) {
        if (processedRepo.existsByClientActionId(action.getClientActionId())) {
            return SyncActionResult.builder().clientActionId(action.getClientActionId())
                    .status("DUPLICATE").reason("Already processed").build();
        }

        try {
            applyAction(action, rangerId);
            processedRepo.save(ProcessedClientAction.builder()
                    .clientActionId(action.getClientActionId())
                    .processedAt(Instant.now(clock)).build());
            return SyncActionResult.builder().clientActionId(action.getClientActionId())
                    .status("APPLIED").build();
        } catch (Exception ex) {
            log.warn("Sync action {} rejected: {}", action.getClientActionId(), ex.getMessage());
            return SyncActionResult.builder().clientActionId(action.getClientActionId())
                    .status("REJECTED").reason(ex.getMessage()).build();
        }
    }

    private void applyAction(SyncActionRequest action, String rangerId) {
        switch (action.getType()) {
            case "ACKNOWLEDGE"       -> alertManager.acknowledge(action.getAlertId(), rangerId);
            case "DECLINE"           -> {
                String reason = getPayloadField(action, "reason", "No reason provided");
                alertManager.decline(action.getAlertId(), rangerId, reason);
            }
            case "CONFIRM_DISPATCH"  -> alertManager.confirmDispatch(action.getAlertId(), rangerId);
            case "FIELD_REPORT"      -> {
                FieldReportRequest fr = objectMapper.convertValue(action.getPayload(), FieldReportRequest.class);
                alertManager.submitFieldReport(action.getAlertId(), rangerId, fr);
            }
            case "LOCATION_UPDATE"   -> {
                LocationUpdateRequest lr = objectMapper.convertValue(action.getPayload(), LocationUpdateRequest.class);
                rangerLocationService.updateLocation(rangerId, lr);
            }
            default -> throw new IllegalArgumentException("Unknown action type: " + action.getType());
        }
    }

    @SuppressWarnings("unchecked")
    private String getPayloadField(SyncActionRequest action, String field, String defaultVal) {
        if (action.getPayload() == null) return defaultVal;
        Object val = action.getPayload().get(field);
        return val != null ? val.toString() : defaultVal;
    }
}