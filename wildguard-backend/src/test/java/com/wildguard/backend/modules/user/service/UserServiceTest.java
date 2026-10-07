package com.wildguard.backend.modules.user.service;

import com.wildguard.backend.common.exception.ResourceNotFoundException;
import com.wildguard.backend.modules.user.dto.RangerProfileResponse;
import com.wildguard.backend.modules.user.model.Role;
import com.wildguard.backend.modules.user.model.User;
import com.wildguard.backend.modules.user.repository.UserRepository;
import com.wildguard.backend.modules.user.service.impl.UserServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("UserService Unit Tests")
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserServiceImpl userService;

    private User sampleUser;

    @BeforeEach
    void setUp() {
        sampleUser = User.builder()
                .id("u-100")
                .username("ranger_kasun")
                .email("kasun@wildguard.org")
                .fullName("Kasun Perera")
                .badgeNumber("WG-2020")
                .role(Role.ROLE_RANGER)
                .assignedPark("Sinharaja Rainforest")
                .phoneNumber("+94778899001")
                .createdAt(Instant.now())
                .build();
    }

    @Test
    @DisplayName("getRangerProfile - Should return profile DTO when user exists")
    void getRangerProfile_Success() {
        when(userRepository.findByUsername("ranger_kasun")).thenReturn(Optional.of(sampleUser));

        RangerProfileResponse profile = userService.getRangerProfile("ranger_kasun");

        assertNotNull(profile);
        assertEquals("u-100", profile.getId());
        assertEquals("ranger_kasun", profile.getUsername());
        assertEquals("kasun@wildguard.org", profile.getEmail());
        assertEquals("Kasun Perera", profile.getFullName());
        assertEquals(Role.ROLE_RANGER, profile.getRole());
        assertEquals("Sinharaja Rainforest", profile.getAssignedPark());

        verify(userRepository, times(1)).findByUsername("ranger_kasun");
    }

    @Test
    @DisplayName("getRangerProfile - Should throw ResourceNotFoundException when user not found")
    void getRangerProfile_NotFound_ThrowsException() {
        when(userRepository.findByUsername("nonexistent")).thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class, () -> userService.getRangerProfile("nonexistent"));
    }

    @Test
    @DisplayName("findById - Should return user when ID exists")
    void findById_Success() {
        when(userRepository.findById("u-100")).thenReturn(Optional.of(sampleUser));

        User user = userService.findById("u-100");

        assertNotNull(user);
        assertEquals("u-100", user.getId());
    }

    @Test
    @DisplayName("findById - Should throw ResourceNotFoundException when ID not found")
    void findById_NotFound_ThrowsException() {
        when(userRepository.findById("invalid-id")).thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class, () -> userService.findById("invalid-id"));
    }
}
