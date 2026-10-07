package com.wildguard.backend.modules.auth.service;

import com.wildguard.backend.common.exception.DuplicateResourceException;
import com.wildguard.backend.modules.auth.dto.AuthResponse;
import com.wildguard.backend.modules.auth.dto.LoginRequest;
import com.wildguard.backend.modules.auth.dto.RegisterRequest;
import com.wildguard.backend.modules.auth.service.impl.AuthServiceImpl;
import com.wildguard.backend.modules.user.model.Role;
import com.wildguard.backend.modules.user.model.User;
import com.wildguard.backend.modules.user.repository.UserRepository;
import com.wildguard.backend.security.jwt.JwtTokenProvider;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("AuthService Unit Tests")
class AuthServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private AuthenticationManager authenticationManager;

    @Mock
    private JwtTokenProvider tokenProvider;

    @InjectMocks
    private AuthServiceImpl authService;

    private RegisterRequest registerRequest;
    private LoginRequest loginRequest;
    private User savedUser;

    @BeforeEach
    void setUp() {
        registerRequest = RegisterRequest.builder()
                .username("ranger_bob")
                .email("bob@wildguard.org")
                .password("Secret123")
                .fullName("Bob Fernando")
                .badgeNumber("WG-1122")
                .role(Role.ROLE_RANGER)
                .assignedPark("Kumana Sector")
                .build();

        loginRequest = LoginRequest.builder()
                .username("ranger_bob")
                .password("Secret123")
                .build();

        savedUser = User.builder()
                .id("mongo-user-1")
                .username("ranger_bob")
                .email("bob@wildguard.org")
                .password("encodedPassword")
                .fullName("Bob Fernando")
                .badgeNumber("WG-1122")
                .role(Role.ROLE_RANGER)
                .assignedPark("Kumana Sector")
                .active(true)
                .build();
    }

    @Test
    @DisplayName("Should successfully register a new user")
    void register_ValidUser_Success() {
        when(userRepository.existsByUsername("ranger_bob")).thenReturn(false);
        when(userRepository.existsByEmail("bob@wildguard.org")).thenReturn(false);
        when(passwordEncoder.encode("Secret123")).thenReturn("encodedPassword");
        when(userRepository.save(any(User.class))).thenReturn(savedUser);
        when(tokenProvider.generateTokenForUser("ranger_bob", Role.ROLE_RANGER.name())).thenReturn("valid.jwt.token");
        when(tokenProvider.getExpirationMs()).thenReturn(86400000L);

        AuthResponse response = authService.register(registerRequest);

        assertNotNull(response);
        assertEquals("ranger_bob", response.getUsername());
        assertEquals("bob@wildguard.org", response.getEmail());
        assertEquals("valid.jwt.token", response.getToken());
        assertEquals(Role.ROLE_RANGER, response.getRole());

        verify(userRepository, times(1)).save(any(User.class));
    }

    @Test
    @DisplayName("Should auto-generate role-based badge number when missing")
    void register_AutoGeneratesBadgeNumber_Success() {
        RegisterRequest requestWithoutBadge = RegisterRequest.builder()
                .username("manager_alice")
                .email("alice@wildguard.org")
                .password("Secret123")
                .fullName("Alice Silva")
                .role(Role.ROLE_MANAGER)
                .assignedPark("Yala Sector")
                .build();

        User savedManager = User.builder()
                .id("mongo-user-mgr")
                .username("manager_alice")
                .email("alice@wildguard.org")
                .password("encodedPassword")
                .fullName("Alice Silva")
                .badgeNumber("WG-MGR-001")
                .role(Role.ROLE_MANAGER)
                .assignedPark("Yala Sector")
                .active(true)
                .build();

        when(userRepository.existsByUsername("manager_alice")).thenReturn(false);
        when(userRepository.existsByEmail("alice@wildguard.org")).thenReturn(false);
        when(userRepository.countByRole(Role.ROLE_MANAGER)).thenReturn(0L);
        when(userRepository.existsByBadgeNumber("WG-MGR-001")).thenReturn(false);
        when(passwordEncoder.encode("Secret123")).thenReturn("encodedPassword");
        when(userRepository.save(any(User.class))).thenReturn(savedManager);
        when(tokenProvider.generateTokenForUser("manager_alice", Role.ROLE_MANAGER.name())).thenReturn("valid.jwt.token");
        when(tokenProvider.getExpirationMs()).thenReturn(86400000L);

        AuthResponse response = authService.register(requestWithoutBadge);

        assertNotNull(response);
        assertEquals("WG-MGR-001", response.getBadgeNumber());
        assertEquals(Role.ROLE_MANAGER, response.getRole());
    }

    @Test
    @DisplayName("getNextBadgeNumber should skip existing badge 001 and return 002")
    void getNextBadgeNumber_SkipsExisting_ReturnsNext() {
        when(userRepository.countByRole(Role.ROLE_RANGER)).thenReturn(1L);
        when(userRepository.existsByBadgeNumber("WG-RNG-002")).thenReturn(false);

        String nextBadge = authService.getNextBadgeNumber(Role.ROLE_RANGER);

        assertEquals("WG-RNG-002", nextBadge);
    }

    @Test
    @DisplayName("Should throw DuplicateResourceException when username exists")
    void register_DuplicateUsername_ThrowsException() {
        when(userRepository.existsByUsername("ranger_bob")).thenReturn(true);

        assertThrows(DuplicateResourceException.class, () -> authService.register(registerRequest));
        verify(userRepository, never()).save(any());
    }

    @Test
    @DisplayName("Should throw DuplicateResourceException when email exists")
    void register_DuplicateEmail_ThrowsException() {
        when(userRepository.existsByUsername("ranger_bob")).thenReturn(false);
        when(userRepository.existsByEmail("bob@wildguard.org")).thenReturn(true);

        assertThrows(DuplicateResourceException.class, () -> authService.register(registerRequest));
        verify(userRepository, never()).save(any());
    }

    @Test
    @DisplayName("Should successfully login user with valid credentials")
    void login_ValidCredentials_Success() {
        Authentication authentication = mock(Authentication.class);
        when(authenticationManager.authenticate(any(UsernamePasswordAuthenticationToken.class)))
                .thenReturn(authentication);
        when(tokenProvider.generateToken(authentication)).thenReturn("login.jwt.token");
        when(userRepository.findByUsername("ranger_bob")).thenReturn(Optional.of(savedUser));
        when(tokenProvider.getExpirationMs()).thenReturn(86400000L);

        AuthResponse response = authService.login(loginRequest);

        assertNotNull(response);
        assertEquals("login.jwt.token", response.getToken());
        assertEquals("ranger_bob", response.getUsername());
    }

    @Test
    @DisplayName("Should throw BadCredentialsException when password does not match")
    void login_InvalidCredentials_ThrowsException() {
        when(authenticationManager.authenticate(any(UsernamePasswordAuthenticationToken.class)))
                .thenThrow(new BadCredentialsException("Bad credentials"));

        assertThrows(BadCredentialsException.class, () -> authService.login(loginRequest));
    }
}
