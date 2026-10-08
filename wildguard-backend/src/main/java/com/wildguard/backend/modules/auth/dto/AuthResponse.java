package com.wildguard.backend.modules.auth.dto;

import com.wildguard.backend.common.constants.AppConstants;
import com.wildguard.backend.modules.user.model.Role;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AuthResponse {

    private String token;

    @Builder.Default
    private String tokenType = AppConstants.TOKEN_TYPE_BEARER;

    private long expiresIn;
    private String userId;
    private String username;
    private String email;
    private String fullName;
    private Role role;
    private String badgeNumber;
    private String assignedPark;
    private String phoneNumber;
}
