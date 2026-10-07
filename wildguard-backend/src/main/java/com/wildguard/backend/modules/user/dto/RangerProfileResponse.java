package com.wildguard.backend.modules.user.dto;

import com.wildguard.backend.modules.user.model.Role;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RangerProfileResponse {

    private String id;
    private String username;
    private String email;
    private String fullName;
    private String badgeNumber;
    private Role role;
    private String assignedPark;
    private String phoneNumber;
    private Instant createdAt;
}
