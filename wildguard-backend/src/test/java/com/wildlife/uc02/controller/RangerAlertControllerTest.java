package com.wildlife.uc02.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.wildguard.backend.modules.user.repository.UserRepository;
import com.wildlife.uc02.dto.DeclineRequest;
import com.wildlife.uc02.dto.FieldReportRequest;
import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.exception.Uc02AccessDeniedException;
import com.wildlife.uc02.exception.Uc02ExceptionHandler;
import com.wildlife.uc02.repository.*;
import com.wildlife.uc02.service.api.AlertManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.security.Principal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ExtendWith(MockitoExtension.class)
@DisplayName("RangerAlertController MockMvc Tests")
class RangerAlertControllerTest {

    private MockMvc mockMvc;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Mock private AlertRepository alertRepository;
    @Mock private CollarRepository collarRepository;
    @Mock private SettlementRepository settlementRepository;
    @Mock private RangerStatusRepository rangerStatusRepository;
    @Mock private ParkRepository parkRepository;
    @Mock private UserRepository userRepository;
    @Mock private AlertManager alertManager;

    @InjectMocks
    private RangerAlertController controller;

    private Principal principal;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new Uc02ExceptionHandler())
                .build();

        principal = () -> "saman_p";
    }

    @Test
    @DisplayName("GET /api/alerts - Returns 200 and list of alerts for assigned ranger")
    void should_getMyAlerts() throws Exception {
        Alert alert = Alert.builder()
                .id("alt-1").displayCode("ALT-0001")
                .status(AlertStatus.NOTIFIED).threatLevel(ThreatLevel.HIGH)
                .animal(Animal.builder().name("Rajah").tagId("ELE-024").build())
                .zone(GeofenceZone.builder().name("Farmland").type(ZoneType.FARMLAND).build())
                .lat(6.37).lng(81.50).breachTime(Instant.now())
                .assignedRangerId("saman_p")
                .build();

        when(alertRepository.findByAssignedRangerId("saman_p")).thenReturn(List.of(alert));

        mockMvc.perform(get("/api/alerts").principal(principal))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value("alt-1"))
                .andExpect(jsonPath("$[0].displayCode").value("ALT-0001"))
                .andExpect(jsonPath("$[0].animalName").value("Rajah"))
                .andExpect(jsonPath("$[0].threatLevel").value("HIGH"));
    }

    @Test
    @DisplayName("GET /api/alerts/{id} - Returns 200 with full alert details for assigned ranger")
    void should_getAlertDetail_whenAssigned() throws Exception {
        Alert alert = Alert.builder()
                .id("alt-1").displayCode("ALT-0001").parkId("park-1")
                .status(AlertStatus.NOTIFIED).threatLevel(ThreatLevel.HIGH)
                .animal(Animal.builder().id("a-1").name("Rajah").species("Elephant").sex("MALE").build())
                .zone(GeofenceZone.builder().name("Farmland").type(ZoneType.FARMLAND).build())
                .lat(6.37).lng(81.50).breachTime(Instant.now())
                .assignedRangerId("saman_p")
                .build();

        when(alertRepository.findById("alt-1")).thenReturn(Optional.of(alert));
        when(settlementRepository.findByParkId("park-1")).thenReturn(List.of());

        mockMvc.perform(get("/api/alerts/alt-1").principal(principal))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value("alt-1"))
                .andExpect(jsonPath("$.displayCode").value("ALT-0001"))
                .andExpect(jsonPath("$.safetyInstructions").isNotEmpty());
    }

    @Test
    @DisplayName("GET /api/alerts/{id} - Returns 403 Forbidden when ranger attempts to view unassigned alert")
    void should_returnForbidden_whenNotAssigned() throws Exception {
        Alert alert = Alert.builder()
                .id("alt-other").displayCode("ALT-0002")
                .assignedRangerId("another_ranger")
                .build();

        when(alertRepository.findById("alt-other")).thenReturn(Optional.of(alert));

        mockMvc.perform(get("/api/alerts/alt-other").principal(principal))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("Forbidden"));
    }

    @Test
    @DisplayName("POST /api/alerts/{id}/acknowledge - Returns 200 OK")
    void should_acknowledgeAlert() throws Exception {
        mockMvc.perform(post("/api/alerts/alt-1/acknowledge").principal(principal))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ACKNOWLEDGED"));

        verify(alertManager).acknowledge(eq("alt-1"), eq("saman_p"));
    }

    @Test
    @DisplayName("POST /api/alerts/{id}/decline - Returns 200 OK and triggers reassignment")
    void should_declineAlert() throws Exception {
        DeclineRequest req = new DeclineRequest();
        req.setReason("Patrol vehicle tire puncture");

        mockMvc.perform(post("/api/alerts/alt-1/decline")
                        .principal(principal)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Alert declined and scheduled for reassignment"));

        verify(alertManager).decline(eq("alt-1"), eq("saman_p"), eq("Patrol vehicle tire puncture"));
    }

    @Test
    @DisplayName("POST /api/alerts/{id}/confirm-dispatch - Returns 200 OK and IN_PROGRESS status")
    void should_confirmDispatch() throws Exception {
        mockMvc.perform(post("/api/alerts/alt-1/confirm-dispatch").principal(principal))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IN_PROGRESS"));

        verify(alertManager).confirmDispatch(eq("alt-1"), eq("saman_p"));
    }

    @Test
    @DisplayName("POST /api/alerts/{id}/field-report - Returns 200 OK")
    void should_submitFieldReport() throws Exception {
        FieldReportRequest req = FieldReportRequest.builder()
                .cropDamage(CropDamage.MINOR)
                .injuries(InjurySeverity.NONE)
                .situationSafe(true)
                .notes("Elephant driven away peacefully")
                .build();

        mockMvc.perform(post("/api/alerts/alt-1/field-report")
                        .principal(principal)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk());

        verify(alertManager).submitFieldReport(eq("alt-1"), eq("saman_p"), any(FieldReportRequest.class));
    }
}
