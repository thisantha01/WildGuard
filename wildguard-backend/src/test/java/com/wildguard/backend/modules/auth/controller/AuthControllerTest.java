package com.wildguard.backend.modules.auth.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.wildguard.backend.common.exception.DuplicateResourceException;
import com.wildguard.backend.common.exception.GlobalExceptionHandler;
import com.wildguard.backend.modules.auth.dto.AuthResponse;
import com.wildguard.backend.modules.auth.dto.LoginRequest;
import com.wildguard.backend.modules.auth.dto.RegisterRequest;
import com.wildguard.backend.modules.auth.service.AuthService;
import com.wildguard.backend.modules.user.model.Role;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("AuthController Unit Tests")
class AuthControllerTest {

    private MockMvc mockMvc;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Mock
    private AuthService authService;

    @InjectMocks
    private AuthController authController;

    private RegisterRequest validRegisterRequest;
    private LoginRequest validLoginRequest;
    private AuthResponse authResponse;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(authController)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();

        validRegisterRequest = RegisterRequest.builder()
                .username("ranger_sam")
                .email("sam@wildguard.org")
                .password("Password123!")
                .fullName("Sam Gamini")
                .badgeNumber("WG-7788")
                .role(Role.ROLE_RANGER)
                .assignedPark("Wilpattu Block A")
                .phoneNumber("+94771234567")
                .build();

        validLoginRequest = LoginRequest.builder()
                .username("ranger_sam")
                .password("Password123!")
                .build();

        authResponse = AuthResponse.builder()
                .token("mocked.jwt.token.sample")
                .tokenType("Bearer")
                .expiresIn(86400000L)
                .userId("mongo-user-id-555")
                .username("ranger_sam")
                .email("sam@wildguard.org")
                .fullName("Sam Gamini")
                .role(Role.ROLE_RANGER)
                .badgeNumber("WG-7788")
                .assignedPark("Wilpattu Block A")
                .build();
    }

    @Nested
    @DisplayName("Positive Path Tests")
    class PositivePathTests {

        @Test
        @DisplayName("POST /api/auth/register - Should return 201 Created on valid Ranger registration")
        void register_ValidRanger_ReturnsCreated() throws Exception {
            when(authService.register(any(RegisterRequest.class))).thenReturn(authResponse);

            mockMvc.perform(post("/api/auth/register")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(validRegisterRequest)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.token").value("mocked.jwt.token.sample"))
                    .andExpect(jsonPath("$.tokenType").value("Bearer"))
                    .andExpect(jsonPath("$.username").value("ranger_sam"))
                    .andExpect(jsonPath("$.role").value("ROLE_RANGER"))
                    .andExpect(jsonPath("$.badgeNumber").value("WG-7788"));

            verify(authService, times(1)).register(any(RegisterRequest.class));
        }

        @Test
        @DisplayName("POST /api/auth/login - Should return 200 OK on valid credentials")
        void login_ValidCredentials_ReturnsOk() throws Exception {
            when(authService.login(any(LoginRequest.class))).thenReturn(authResponse);

            mockMvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(validLoginRequest)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.token").value("mocked.jwt.token.sample"))
                    .andExpect(jsonPath("$.username").value("ranger_sam"));

            verify(authService, times(1)).login(any(LoginRequest.class));
        }

        @Test
        @DisplayName("POST /api/auth/register - Should support MANAGER role registration")
        void register_WithManagerRole_Success() throws Exception {
            validRegisterRequest.setRole(Role.ROLE_MANAGER);
            authResponse.setRole(Role.ROLE_MANAGER);
            when(authService.register(any(RegisterRequest.class))).thenReturn(authResponse);

            mockMvc.perform(post("/api/auth/register")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(validRegisterRequest)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.role").value("ROLE_MANAGER"));
        }

        @Test
        @DisplayName("POST /api/auth/register - Should support LIAISON role registration")
        void register_WithLiaisonRole_Success() throws Exception {
            validRegisterRequest.setRole(Role.ROLE_LIAISON);
            authResponse.setRole(Role.ROLE_LIAISON);
            when(authService.register(any(RegisterRequest.class))).thenReturn(authResponse);

            mockMvc.perform(post("/api/auth/register")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(validRegisterRequest)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.role").value("ROLE_LIAISON"));
        }

        @Test
        @DisplayName("GET /api/auth/next-badge - Should return next available badge number")
        void getNextBadgeNumber_Success() throws Exception {
            when(authService.getNextBadgeNumber(Role.ROLE_RANGER)).thenReturn("WG-RNG-002");

            mockMvc.perform(get("/api/auth/next-badge")
                            .param("role", "RANGER"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.badgeNumber").value("WG-RNG-002"));

            verify(authService, times(1)).getNextBadgeNumber(Role.ROLE_RANGER);
        }
    }

    @Nested
    @DisplayName("Negative Path Tests")
    class NegativePathTests {

        @Test
        @DisplayName("POST /api/auth/register - Should return 409 Conflict when username is already taken")
        void register_DuplicateUsername_ReturnsConflict() throws Exception {
            when(authService.register(any(RegisterRequest.class)))
                    .thenThrow(new DuplicateResourceException("Username is already taken: ranger_sam"));

            mockMvc.perform(post("/api/auth/register")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(validRegisterRequest)))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.status").value(409))
                    .andExpect(jsonPath("$.message").value("Username is already taken: ranger_sam"));

            verify(authService, times(1)).register(any(RegisterRequest.class));
        }

        @Test
        @DisplayName("POST /api/auth/register - Should return 409 Conflict when email is already registered")
        void register_DuplicateEmail_ReturnsConflict() throws Exception {
            when(authService.register(any(RegisterRequest.class)))
                    .thenThrow(new DuplicateResourceException("Email is already registered: sam@wildguard.org"));

            mockMvc.perform(post("/api/auth/register")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(validRegisterRequest)))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.status").value(409))
                    .andExpect(jsonPath("$.message").value("Email is already registered: sam@wildguard.org"));

            verify(authService, times(1)).register(any(RegisterRequest.class));
        }

        @Test
        @DisplayName("POST /api/auth/register - Should return 400 Bad Request when validation fails (invalid email)")
        void register_InvalidEmail_ReturnsBadRequest() throws Exception {
            validRegisterRequest.setEmail("not-a-valid-email");

            mockMvc.perform(post("/api/auth/register")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(validRegisterRequest)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.status").value(400))
                    .andExpect(jsonPath("$.fieldErrors.email").exists());

            verify(authService, never()).register(any());
        }

        @Test
        @DisplayName("POST /api/auth/register - Should return 400 Bad Request when password is too short")
        void register_ShortPassword_ReturnsBadRequest() throws Exception {
            validRegisterRequest.setPassword("123");

            mockMvc.perform(post("/api/auth/register")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(validRegisterRequest)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.status").value(400))
                    .andExpect(jsonPath("$.fieldErrors.password").exists());

            verify(authService, never()).register(any());
        }

        @Test
        @DisplayName("POST /api/auth/login - Should return 401 Unauthorized on bad credentials")
        void login_BadCredentials_ReturnsUnauthorized() throws Exception {
            when(authService.login(any(LoginRequest.class)))
                    .thenThrow(new BadCredentialsException("Bad credentials"));

            mockMvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(validLoginRequest)))
                    .andExpect(status().isUnauthorized())
                    .andExpect(jsonPath("$.status").value(401))
                    .andExpect(jsonPath("$.message").value("Invalid username or password"));

            verify(authService, times(1)).login(any(LoginRequest.class));
        }
    }
}
