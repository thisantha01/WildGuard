package com.wildguard.backend.modules.incident.service.impl;

import com.wildguard.backend.common.constants.AppConstants;
import com.wildguard.backend.common.exception.ResourceNotFoundException;
import com.wildguard.backend.common.exception.ValidationException;
import com.wildguard.backend.modules.incident.dto.IncidentBatchSyncRequest;
import com.wildguard.backend.modules.incident.dto.IncidentBatchSyncResponse;
import com.wildguard.backend.modules.incident.dto.IncidentResponse;
import com.wildguard.backend.modules.incident.dto.IncidentSyncRequest;
import com.wildguard.backend.modules.incident.dto.IncidentSyncResponse;
import com.wildguard.backend.modules.incident.model.GeoLocation;
import com.wildguard.backend.modules.incident.model.Incident;
import com.wildguard.backend.modules.incident.model.SyncStatus;
import com.wildguard.backend.modules.incident.repository.IncidentRepository;
import com.wildguard.backend.modules.incident.service.IncidentService;
import com.wildguard.backend.modules.user.model.User;
import com.wildguard.backend.modules.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class IncidentServiceImpl implements IncidentService {

    private final IncidentRepository incidentRepository;
    private final UserRepository userRepository;

    @Override
    public IncidentSyncResponse syncIncident(IncidentSyncRequest request, String rangerUsername) {
        log.info("Processing incident sync request from Ranger '{}', Local ID: '{}'",
                rangerUsername, request.getLocalIncidentId());

        validateSyncRequest(request);

        User ranger = userRepository.findByUsername(rangerUsername)
                .orElseThrow(() -> new ResourceNotFoundException("Ranger user not found: " + rangerUsername));

        // Check for potential duplicate within 24-hour window and identical location
        boolean isDuplicate = false;
        String duplicateReason = null;

        Instant windowStart = request.getTimestamp().minus(Duration.ofHours(AppConstants.DUPLICATE_TIME_WINDOW_HOURS));
        Instant windowEnd = request.getTimestamp().plus(Duration.ofHours(AppConstants.DUPLICATE_TIME_WINDOW_HOURS));

        List<Incident> existingIncidents = incidentRepository.findByTypeAndTimestampBetween(
                request.getType(), windowStart, windowEnd
        );

        Optional<Incident> matchingDuplicate = existingIncidents.stream()
                .filter(existing -> isSameLocation(existing.getLocation(), request.getLatitude(), request.getLongitude()))
                .findFirst();

        if (matchingDuplicate.isPresent()) {
            isDuplicate = true;
            duplicateReason = String.format(
                    "Potential duplicate flagged: Matches incident ID '%s' of type '%s' recorded within 24 hours.",
                    matchingDuplicate.get().getId(), request.getType()
            );
            log.warn("Potential duplicate detected for Local ID '{}': {}", request.getLocalIncidentId(), duplicateReason);
        }

        Incident incident = Incident.builder()
                .localIncidentId(request.getLocalIncidentId())
                .rangerId(ranger.getId())
                .rangerUsername(ranger.getUsername())
                .type(request.getType())
                .severity(request.getSeverity())
                .description(request.getDescription())
                .location(GeoLocation.builder()
                        .latitude(request.getLatitude())
                        .longitude(request.getLongitude())
                        .build())
                .photoBase64(request.getPhotoBase64())
                .timestamp(request.getTimestamp())
                .duplicateFlag(isDuplicate)
                .duplicateReason(duplicateReason)
                .syncStatus(isDuplicate ? SyncStatus.SYNCED_DUPLICATE_FLAGGED : SyncStatus.SYNCED)
                .syncedAt(Instant.now())
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();

        Incident savedIncident = incidentRepository.save(incident);
        log.info("Successfully persisted synced incident with Server ID '{}' for Local ID '{}'",
                savedIncident.getId(), request.getLocalIncidentId());

        return IncidentSyncResponse.builder()
                .localIncidentId(request.getLocalIncidentId())
                .serverIncidentId(savedIncident.getId())
                .status(isDuplicate ? AppConstants.SYNC_STATUS_DUPLICATE : AppConstants.SYNC_STATUS_SUCCESS)
                .message(isDuplicate
                        ? "Incident synced with duplicate warning: record saved successfully."
                        : "Incident synchronized successfully.")
                .duplicateFlag(isDuplicate)
                .duplicateReason(duplicateReason)
                .syncedAt(savedIncident.getSyncedAt())
                .build();
    }

    @Override
    public IncidentBatchSyncResponse syncBatch(IncidentBatchSyncRequest batchRequest, String rangerUsername) {
        log.info("Processing batch sync containing {} incidents for Ranger '{}'",
                batchRequest.getIncidents().size(), rangerUsername);

        List<IncidentSyncResponse> responses = new ArrayList<>();
        int duplicates = 0;

        for (IncidentSyncRequest req : batchRequest.getIncidents()) {
            IncidentSyncResponse resp = syncIncident(req, rangerUsername);
            if (resp.isDuplicateFlag()) {
                duplicates++;
            }
            responses.add(resp);
        }

        return IncidentBatchSyncResponse.builder()
                .totalSubmitted(batchRequest.getIncidents().size())
                .totalSynced(responses.size())
                .duplicatesFlagged(duplicates)
                .syncResults(responses)
                .build();
    }

    @Override
    public List<IncidentResponse> getRangerIncidentHistory(String rangerUsername) {
        log.info("Fetching incident history for Ranger '{}'", rangerUsername);

        List<Incident> incidents = incidentRepository.findByRangerUsernameOrderByTimestampDesc(rangerUsername);

        return incidents.stream()
                .map(this::mapToIncidentResponse)
                .collect(Collectors.toList());
    }

    private void validateSyncRequest(IncidentSyncRequest request) {
        if (request.getLocalIncidentId() == null || request.getLocalIncidentId().trim().isEmpty()) {
            throw new ValidationException("Local incident ID cannot be null or blank");
        }

        if (request.getType() == null) {
            throw new ValidationException("Incident type cannot be null");
        }

        if (request.getSeverity() == null) {
            throw new ValidationException("Incident severity cannot be null");
        }

        if (request.getDescription() == null || request.getDescription().trim().isEmpty()) {
            throw new ValidationException("Incident description cannot be null or blank");
        }

        if (request.getLatitude() == null) {
            throw new ValidationException("Latitude coordinate is required");
        }

        if (request.getLatitude() < AppConstants.MIN_LATITUDE || request.getLatitude() > AppConstants.MAX_LATITUDE) {
            throw new ValidationException(String.format(
                    "Invalid latitude value: %f. Must be between %f and %f.",
                    request.getLatitude(), AppConstants.MIN_LATITUDE, AppConstants.MAX_LATITUDE));
        }

        if (request.getLongitude() == null) {
            throw new ValidationException("Longitude coordinate is required");
        }

        if (request.getLongitude() < AppConstants.MIN_LONGITUDE || request.getLongitude() > AppConstants.MAX_LONGITUDE) {
            throw new ValidationException(String.format(
                    "Invalid longitude value: %f. Must be between %f and %f.",
                    request.getLongitude(), AppConstants.MIN_LONGITUDE, AppConstants.MAX_LONGITUDE));
        }

        if (request.getTimestamp() == null) {
            throw new ValidationException("Incident timestamp is required");
        }

        // Allow up to 10 minutes clock skew in the future
        Instant maxAllowedFuture = Instant.now().plus(Duration.ofMinutes(10));
        if (request.getTimestamp().isAfter(maxAllowedFuture)) {
            throw new ValidationException("Incident timestamp cannot be in the future");
        }
    }

    private boolean isSameLocation(GeoLocation existingLocation, Double reqLat, Double reqLon) {
        if (existingLocation == null || existingLocation.getLatitude() == null || existingLocation.getLongitude() == null) {
            return false;
        }

        double latDiff = Math.abs(existingLocation.getLatitude() - reqLat);
        double lonDiff = Math.abs(existingLocation.getLongitude() - reqLon);

        return latDiff < AppConstants.DUPLICATE_GEO_THRESHOLD_DELTA
                && lonDiff < AppConstants.DUPLICATE_GEO_THRESHOLD_DELTA;
    }

    private IncidentResponse mapToIncidentResponse(Incident incident) {
        Double lat = incident.getLocation() != null ? incident.getLocation().getLatitude() : null;
        Double lon = incident.getLocation() != null ? incident.getLocation().getLongitude() : null;

        return IncidentResponse.builder()
                .id(incident.getId())
                .localIncidentId(incident.getLocalIncidentId())
                .rangerId(incident.getRangerId())
                .rangerUsername(incident.getRangerUsername())
                .type(incident.getType())
                .severity(incident.getSeverity())
                .description(incident.getDescription())
                .latitude(lat)
                .longitude(lon)
                .photoBase64(incident.getPhotoBase64())
                .timestamp(incident.getTimestamp())
                .duplicateFlag(incident.isDuplicateFlag())
                .duplicateReason(incident.getDuplicateReason())
                .syncStatus(incident.getSyncStatus())
                .syncedAt(incident.getSyncedAt())
                .build();
    }
}
