package com.wildguard.backend.modules.user.controller;

import com.wildguard.backend.common.exception.GlobalExceptionHandler;
import com.wildguard.backend.modules.user.dto.RangerProfileResponse;
import com.wildguard.backend.modules.user.model.Role;
import com.wildguard.backend.modules.user.service.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.security.Principal;
import java.time.Instant;

import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("RangerController Unit Tests")
class RangerControllerTest {

    private MockMvc mockMvc;

    @Mock
    private UserService userService;

    @InjectMocks
    private RangerController rangerController;

    private RangerProfileResponse profileResponse;
    private Principal principal;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(rangerController)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();

        principal = () -> "ranger_sarath";

        profileResponse = RangerProfileResponse.builder()
                .id("ranger-id-777")
                .username("ranger_sarath")
                .email("sarath@wildguard.org")
                .fullName("Sarath Wickrama")
                .badgeNumber("WG-3040")
                .role(Role.ROLE_RANGER)
                .assignedPark("Kumana East")
                .phoneNumber("+94711122334")
                .createdAt(Instant.now())
                .build();
    }

    @Test
    @DisplayName("GET /api/rangers/me - Returns 200 OK and Ranger profile")
    void getCurrentRangerProfile_Success() throws Exception {
        when(userService.getRangerProfile("ranger_sarath")).thenReturn(profileResponse);

        mockMvc.perform(get("/api/rangers/me")
                        .principal(principal))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value("ranger-id-777"))
                .andExpect(jsonPath("$.username").value("ranger_sarath"))
                .andExpect(jsonPath("$.fullName").value("Sarath Wickrama"))
                .andExpect(jsonPath("$.badgeNumber").value("WG-3040"))
                .andExpect(jsonPath("$.role").value("ROLE_RANGER"))
                .andExpect(jsonPath("$.assignedPark").value("Kumana East"));

        verify(userService, times(1)).getRangerProfile("ranger_sarath");
    }
}
