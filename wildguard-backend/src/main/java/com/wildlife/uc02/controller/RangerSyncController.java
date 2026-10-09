package com.wildlife.uc02.controller;

import com.wildguard.backend.modules.user.model.User;
import com.wildguard.backend.modules.user.repository.UserRepository;
import com.wildlife.uc02.dto.LocationUpdateRequest;
import com.wildlife.uc02.dto.SyncBatchRequest;
import com.wildlife.uc02.dto.SyncBatchResponse;
import com.wildlife.uc02.entity.RangerStatus;
import com.wildlife.uc02.service.api.RangerLocationService;
import com.wildlife.uc02.service.api.SyncService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.Map;

/**
 * Controller for offline actions synchronization, location updates, and heartbeats.
 */
@Slf4j
@RestController
@RequiredArgsConstructor
@Tag(name = "Ranger Sync & Telemetry", description = "Endpoints for offline batch synchronization and patrol location/heartbeat tracking")
public class RangerSyncController {

    private final SyncService syncService;
    private final RangerLocationService rangerLocationService;
    private final UserRepository userRepository;

    @PostMapping("/api/sync")
    @PreAuthorize("hasRole('RANGER')")
    @Operation(summary = "Batch offline actions sync", description = "Idempotently processes offline ranger action queue and returns per-action results")
    public ResponseEntity<SyncBatchResponse> syncActions(
            @RequestBody @Valid SyncBatchRequest request,
            Principal principal) {
        String rangerId = resolveRangerId(principal);
        SyncBatchResponse response = syncService.process(request, rangerId);
        return ResponseEntity.ok(response);
    }

    @PutMapping("/api/rangers/me/location")
    @PreAuthorize("hasRole('RANGER')")
    @Operation(summary = "Update current patrol location", description = "Updates current ranger GPS coordinates and timestamp")
    public ResponseEntity<RangerStatus> updateLocation(
            @RequestBody @Valid LocationUpdateRequest request,
            Principal principal) {
        String rangerId = resolveRangerId(principal);
        RangerStatus updated = rangerLocationService.updateLocation(rangerId, request);
        return ResponseEntity.ok(updated);
    }

    @PostMapping("/api/rangers/me/heartbeat")
    @PreAuthorize("hasRole('RANGER')")
    @Operation(summary = "Send ranger heartbeat", description = "Keeps ranger availability active and refreshes connectivity timestamp")
    public ResponseEntity<Map<String, String>> heartbeat(Principal principal) {
        String rangerId = resolveRangerId(principal);
        rangerLocationService.heartbeat(rangerId);
        return ResponseEntity.ok(Map.of("message", "Heartbeat received"));
    }

    private String resolveRangerId(Principal principal) {
        if (principal == null) return "ranger_unknown";
        String username = principal.getName();
        return userRepository.findByUsername(username)
                .map(User::getId)
                .orElse(username);
    }
}
