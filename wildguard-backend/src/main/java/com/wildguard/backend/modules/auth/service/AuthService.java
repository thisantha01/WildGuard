package com.wildguard.backend.modules.auth.service;

import com.wildguard.backend.modules.auth.dto.AuthResponse;
import com.wildguard.backend.modules.auth.dto.LoginRequest;
import com.wildguard.backend.modules.auth.dto.RegisterRequest;
import com.wildguard.backend.modules.user.model.Role;

public interface AuthService {

    AuthResponse register(RegisterRequest request);

    AuthResponse login(LoginRequest request);

    String getNextBadgeNumber(Role role);
}
