package com.wildguard.backend.modules.incident.service;

import com.wildguard.backend.common.exception.ResourceNotFoundException;
import com.wildguard.backend.common.exception.ValidationException;
import com.wildguard.backend.modules.incident.dto.IncidentBatchSyncRequest;
import com.wildguard.backend.modules.incident.dto.IncidentBatchSyncResponse;
import com.wildguard.backend.modules.incident.dto.IncidentResponse;
import com.wildguard.backend.modules.incident.dto.IncidentSyncRequest;
import com.wildguard.backend.modules.incident.dto.IncidentSyncResponse;
import com.wildguard.backend.modules.incident.model.GeoLocation;
import com.wildguard.backend.modules.incident.model.Incident;
import com.wildguard.backend.modules.incident.model.IncidentSeverity;
import com.wildguard.backend.modules.incident.model.IncidentType;
import com.wildguard.backend.modules.incident.model.SyncStatus;
import com.wildguard.backend.modules.incident.repository.IncidentRepository;
import com.wildguard.backend.modules.incident.service.impl.IncidentServiceImpl;
import com.wildguard.backend.modules.user.model.Role;
import com.wildguard.backend.modules.user.model.User;
import com.wildguard.backend.modules.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Duration;
import java.time.Instant;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("IncidentService Unit Tests")
class IncidentServiceTest {

    @Mock
    private IncidentRepository incidentRepository;

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private IncidentServiceImpl incidentService;

    private User sampleRanger;
    private IncidentSyncRequest validSyncRequest;
    private Instant now;

    @BeforeEach
    void setUp() {
        now = Instant.now();

        sampleRanger = User.builder()
                .id("ranger-mongo-123")
                .username("ranger_john")
                .email("john@wildguard.org")
                .fullName("John Silva")
                .badgeNumber("WG-4091")
                .role(Role.ROLE_RANGER)
                .assignedPark("Yala Sector 2")
                .build();

        validSyncRequest = IncidentSyncRequest.builder()
                .localIncidentId("local-uuid-001")
                .type(IncidentType.SNARE)
                .severity(IncidentSeverity.HIGH)
                .description("Wire snare trap found near waterhole")
                .latitude(6.3685)
                .longitude(81.5273)
                .photoBase64("data:image/jpeg;base64,/9j/4AAQSkZJRg==")
                .timestamp(now.minus(Duration.ofHours(2)))
                .build();
    }

    @Nested
    @DisplayName("Positive Path Tests")
    class PositivePathTests {

        @Test
        @DisplayName("Should successfully sync valid offline incident and map IDs")
        void syncIncident_ValidRequest_Success() {
            // Given
            when(userRepository.findByUsername("ranger_john")).thenReturn(Optional.of(sampleRanger));
            when(incidentRepository.findByTypeAndTimestampBetween(eq(IncidentType.SNARE), any(Instant.class), any(Instant.class)))
                    .thenReturn(Collections.emptyList());

            Incident savedIncident = Incident.builder()
                    .id("mongo-id-999")
                    .localIncidentId("local-uuid-001")
                    .rangerId(sampleRanger.getId())
                    .rangerUsername(sampleRanger.getUsername())
                    .type(validSyncRequest.getType())
                    .severity(validSyncRequest.getSeverity())
                    .description(validSyncRequest.getDescription())
                    .location(new GeoLocation(validSyncRequest.getLatitude(), validSyncRequest.getLongitude()))
                    .photoBase64(validSyncRequest.getPhotoBase64())
                    .timestamp(validSyncRequest.getTimestamp())
                    .duplicateFlag(false)
                    .syncStatus(SyncStatus.SYNCED)
                    .syncedAt(Instant.now())
                    .build();

            when(incidentRepository.save(any(Incident.class))).thenReturn(savedIncident);

            // When
            IncidentSyncResponse response = incidentService.syncIncident(validSyncRequest, "ranger_john");

            // Then
            assertNotNull(response);
            assertEquals("local-uuid-001", response.getLocalIncidentId());
            assertEquals("mongo-id-999", response.getServerIncidentId());
            assertEquals("SYNCED", response.getStatus());
            assertFalse(response.isDuplicateFlag());
            assertNull(response.getDuplicateReason());
            assertNotNull(response.getSyncedAt());

            verify(userRepository, times(1)).findByUsername("ranger_john");
            verify(incidentRepository, times(1)).save(any(Incident.class));
        }

        @Test
        @DisplayName("Should successfully sync a batch of offline incidents")
        void syncBatch_ValidRequests_Success() {
            // Given
            when(userRepository.findByUsername("ranger_john")).thenReturn(Optional.of(sampleRanger));
            when(incidentRepository.findByTypeAndTimestampBetween(any(IncidentType.class), any(Instant.class), any(Instant.class)))
                    .thenReturn(Collections.emptyList());

            Incident savedIncident = Incident.builder()
                    .id("mongo-batch-id-1")
                    .localIncidentId("local-uuid-001")
                    .build();
            when(incidentRepository.save(any(Incident.class))).thenReturn(savedIncident);

            IncidentBatchSyncRequest batchRequest = IncidentBatchSyncRequest.builder()
                    .incidents(List.of(validSyncRequest))
                    .build();

            // When
            IncidentBatchSyncResponse batchResponse = incidentService.syncBatch(batchRequest, "ranger_john");

            // Then
            assertNotNull(batchResponse);
            assertEquals(1, batchResponse.getTotalSubmitted());
            assertEquals(1, batchResponse.getTotalSynced());
            assertEquals(0, batchResponse.getDuplicatesFlagged());
            assertEquals(1, batchResponse.getSyncResults().size());
            assertEquals("mongo-batch-id-1", batchResponse.getSyncResults().get(0).getServerIncidentId());
        }

        @Test
        @DisplayName("Should return ranger incident history sorted properly")
        void getRangerIncidentHistory_Success() {
            // Given
            Incident historyIncident = Incident.builder()
                    .id("mongo-hist-1")
                    .localIncidentId("local-hist-1")
                    .rangerId(sampleRanger.getId())
                    .rangerUsername(sampleRanger.getUsername())
                    .type(IncidentType.CARCASS)
                    .severity(IncidentSeverity.CRITICAL)
                    .description("Poached elephant carcass found")
                    .location(new GeoLocation(6.3685, 81.5273))
                    .timestamp(now.minus(Duration.ofDays(1)))
                    .syncStatus(SyncStatus.SYNCED)
                    .duplicateFlag(false)
                    .syncedAt(now)
                    .build();

            when(incidentRepository.findByRangerUsernameOrderByTimestampDesc("ranger_john"))
                    .thenReturn(List.of(historyIncident));

            // When
            List<IncidentResponse> history = incidentService.getRangerIncidentHistory("ranger_john");

            // Then
            assertNotNull(history);
            assertEquals(1, history.size());
            IncidentResponse item = history.get(0);
            assertEquals("mongo-hist-1", item.getId());
            assertEquals("local-hist-1", item.getLocalIncidentId());
            assertEquals(IncidentType.CARCASS, item.getType());
            assertEquals(IncidentSeverity.CRITICAL, item.getSeverity());
            assertEquals(6.3685, item.getLatitude());
            assertEquals(81.5273, item.getLongitude());

            verify(incidentRepository, times(1)).findByRangerUsernameOrderByTimestampDesc("ranger_john");
        }
    }

    @Nested
    @DisplayName("Negative Path Tests (Validation & Errors)")
    class NegativePathTests {

        @Test
        @DisplayName("Should throw ValidationException when localIncidentId is blank")
        void syncIncident_BlankLocalIncidentId_ThrowsValidationException() {
            validSyncRequest.setLocalIncidentId("  ");

            ValidationException ex = assertThrows(ValidationException.class,
                    () -> incidentService.syncIncident(validSyncRequest, "ranger_john"));

            assertTrue(ex.getMessage().contains("Local incident ID"));
            verify(incidentRepository, never()).save(any());
        }

        @Test
        @DisplayName("Should throw ValidationException when latitude is null")
        void syncIncident_MissingLatitude_ThrowsValidationException() {
            validSyncRequest.setLatitude(null);

            ValidationException ex = assertThrows(ValidationException.class,
                    () -> incidentService.syncIncident(validSyncRequest, "ranger_john"));

            assertTrue(ex.getMessage().contains("Latitude coordinate is required"));
            verify(incidentRepository, never()).save(any());
        }

        @Test
        @DisplayName("Should throw ValidationException when latitude is out of bounds")
        void syncIncident_LatitudeOutOfBounds_ThrowsValidationException() {
            validSyncRequest.setLatitude(95.5);

            ValidationException ex = assertThrows(ValidationException.class,
                    () -> incidentService.syncIncident(validSyncRequest, "ranger_john"));

            assertTrue(ex.getMessage().contains("Invalid latitude value"));
            verify(incidentRepository, never()).save(any());
        }

        @Test
        @DisplayName("Should throw ValidationException when longitude is null")
        void syncIncident_MissingLongitude_ThrowsValidationException() {
            validSyncRequest.setLongitude(null);

            ValidationException ex = assertThrows(ValidationException.class,
                    () -> incidentService.syncIncident(validSyncRequest, "ranger_john"));

            assertTrue(ex.getMessage().contains("Longitude coordinate is required"));
            verify(incidentRepository, never()).save(any());
        }

        @Test
        @DisplayName("Should throw ValidationException when longitude is out of bounds")
        void syncIncident_LongitudeOutOfBounds_ThrowsValidationException() {
            validSyncRequest.setLongitude(-195.0);

            ValidationException ex = assertThrows(ValidationException.class,
                    () -> incidentService.syncIncident(validSyncRequest, "ranger_john"));

            assertTrue(ex.getMessage().contains("Invalid longitude value"));
            verify(incidentRepository, never()).save(any());
        }

        @Test
        @DisplayName("Should throw ValidationException when timestamp is null")
        void syncIncident_NullTimestamp_ThrowsValidationException() {
            validSyncRequest.setTimestamp(null);

            ValidationException ex = assertThrows(ValidationException.class,
                    () -> incidentService.syncIncident(validSyncRequest, "ranger_john"));

            assertTrue(ex.getMessage().contains("timestamp is required"));
            verify(incidentRepository, never()).save(any());
        }

        @Test
        @DisplayName("Should throw ValidationException when timestamp is in future")
        void syncIncident_FutureTimestamp_ThrowsValidationException() {
            validSyncRequest.setTimestamp(Instant.now().plus(Duration.ofDays(1)));

            ValidationException ex = assertThrows(ValidationException.class,
                    () -> incidentService.syncIncident(validSyncRequest, "ranger_john"));

            assertTrue(ex.getMessage().contains("cannot be in the future"));
            verify(incidentRepository, never()).save(any());
        }

        @Test
        @DisplayName("Should throw ResourceNotFoundException when ranger user does not exist")
        void syncIncident_RangerNotFound_ThrowsResourceNotFoundException() {
            when(userRepository.findByUsername("unknown_ranger")).thenReturn(Optional.empty());

            ResourceNotFoundException ex = assertThrows(ResourceNotFoundException.class,
                    () -> incidentService.syncIncident(validSyncRequest, "unknown_ranger"));

            assertTrue(ex.getMessage().contains("Ranger user not found"));
            verify(incidentRepository, never()).save(any());
        }
    }

    @Nested
    @DisplayName("Edge Cases (Duplicate Detection Logic)")
    class DuplicateDetectionEdgeCases {

        @Test
        @DisplayName("Should flag duplicate when same type and location was logged within 24 hours, but persist successfully")
        void syncIncident_DuplicateSameTypeAndLocationWithin24Hours_FlagsDuplicateWithoutError() {
            // Given: An existing incident recorded 3 hours prior with exact same type and location
            when(userRepository.findByUsername("ranger_john")).thenReturn(Optional.of(sampleRanger));

            Incident existingIncident = Incident.builder()
                    .id("existing-mongo-id-100")
                    .type(IncidentType.SNARE)
                    .location(new GeoLocation(6.3685, 81.5273)) // Exact same coords
                    .timestamp(validSyncRequest.getTimestamp().minus(Duration.ofHours(3)))
                    .build();

            when(incidentRepository.findByTypeAndTimestampBetween(eq(IncidentType.SNARE), any(Instant.class), any(Instant.class)))
                    .thenReturn(List.of(existingIncident));

            Incident savedIncidentWithFlag = Incident.builder()
                    .id("new-mongo-id-101")
                    .localIncidentId(validSyncRequest.getLocalIncidentId())
                    .duplicateFlag(true)
                    .duplicateReason("Potential duplicate flagged: Matches incident ID 'existing-mongo-id-100'")
                    .syncStatus(SyncStatus.SYNCED_DUPLICATE_FLAGGED)
                    .syncedAt(Instant.now())
                    .build();

            when(incidentRepository.save(any(Incident.class))).thenReturn(savedIncidentWithFlag);

            // When: Ranger syncs the duplicate incident
            IncidentSyncResponse response = incidentService.syncIncident(validSyncRequest, "ranger_john");

            // Then: Must NOT throw an exception, must save and flag duplicate
            assertNotNull(response);
            assertEquals("local-uuid-001", response.getLocalIncidentId());
            assertEquals("new-mongo-id-101", response.getServerIncidentId());
            assertTrue(response.isDuplicateFlag(), "Duplicate flag must be TRUE");
            assertEquals("SYNCED_DUPLICATE_FLAGGED", response.getStatus());
            assertNotNull(response.getDuplicateReason());
            assertTrue(response.getDuplicateReason().contains("existing-mongo-id-100"));

            verify(incidentRepository, times(1)).save(any(Incident.class));
        }

        @Test
        @DisplayName("Should NOT flag duplicate when coordinates differ significantly")
        void syncIncident_DifferentLocation_NotFlaggedAsDuplicate() {
            // Given: An existing incident with different coordinates
            when(userRepository.findByUsername("ranger_john")).thenReturn(Optional.of(sampleRanger));

            Incident existingIncident = Incident.builder()
                    .id("existing-mongo-id-200")
                    .type(IncidentType.SNARE)
                    .location(new GeoLocation(6.5000, 81.7000)) // Far away
                    .timestamp(validSyncRequest.getTimestamp().minus(Duration.ofHours(2)))
                    .build();

            when(incidentRepository.findByTypeAndTimestampBetween(eq(IncidentType.SNARE), any(Instant.class), any(Instant.class)))
                    .thenReturn(List.of(existingIncident));

            Incident savedIncident = Incident.builder()
                    .id("new-mongo-id-201")
                    .localIncidentId(validSyncRequest.getLocalIncidentId())
                    .duplicateFlag(false)
                    .syncedAt(Instant.now())
                    .build();

            when(incidentRepository.save(any(Incident.class))).thenReturn(savedIncident);

            // When
            IncidentSyncResponse response = incidentService.syncIncident(validSyncRequest, "ranger_john");

            // Then
            assertFalse(response.isDuplicateFlag(), "Different coordinates must NOT be flagged as duplicate");
            verify(incidentRepository, times(1)).save(any(Incident.class));
        }

        @Test
        @DisplayName("Should NOT flag duplicate when location matches but type is different")
        void syncIncident_DifferentType_NotFlaggedAsDuplicate() {
            // Given: Same location, but queried repository returns empty for SNARE (since existing is CARCASS)
            when(userRepository.findByUsername("ranger_john")).thenReturn(Optional.of(sampleRanger));
            when(incidentRepository.findByTypeAndTimestampBetween(eq(IncidentType.SNARE), any(Instant.class), any(Instant.class)))
                    .thenReturn(Collections.emptyList());

            Incident savedIncident = Incident.builder()
                    .id("new-mongo-id-301")
                    .localIncidentId(validSyncRequest.getLocalIncidentId())
                    .duplicateFlag(false)
                    .syncedAt(Instant.now())
                    .build();

            when(incidentRepository.save(any(Incident.class))).thenReturn(savedIncident);

            // When
            IncidentSyncResponse response = incidentService.syncIncident(validSyncRequest, "ranger_john");

            // Then
            assertFalse(response.isDuplicateFlag());
            verify(incidentRepository, times(1)).save(any(Incident.class));
        }
    }
}
