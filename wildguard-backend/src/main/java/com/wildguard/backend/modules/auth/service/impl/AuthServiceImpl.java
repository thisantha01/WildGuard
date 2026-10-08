package com.wildguard.backend.modules.auth.service.impl;

import com.wildguard.backend.common.exception.DuplicateResourceException;
import com.wildguard.backend.modules.auth.dto.AuthResponse;
import com.wildguard.backend.modules.auth.dto.LoginRequest;
import com.wildguard.backend.modules.auth.dto.RegisterRequest;
import com.wildguard.backend.modules.auth.service.AuthService;
import com.wildguard.backend.modules.user.model.Role;
import com.wildguard.backend.modules.user.model.User;
import com.wildguard.backend.modules.user.repository.UserRepository;
import com.wildguard.backend.security.jwt.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthServiceImpl implements AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtTokenProvider tokenProvider;

    @Override
    public AuthResponse register(RegisterRequest request) {
        log.info("Processing registration request for username: {}", request.getUsername());

        if (userRepository.existsByUsername(request.getUsername())) {
            log.warn("Registration rejected: Username '{}' already in use", request.getUsername());
            throw new DuplicateResourceException("Username is already taken: " + request.getUsername());
        }

        if (userRepository.existsByEmail(request.getEmail())) {
            log.warn("Registration rejected: Email '{}' already in use", request.getEmail());
            throw new DuplicateResourceException("Email is already registered: " + request.getEmail());
        }

        Role assignedRole = (request.getRole() != null) ? request.getRole() : Role.ROLE_RANGER;
        String assignedBadgeNumber = resolveOrGenerateBadgeNumber(request.getBadgeNumber(), assignedRole);

        User user = User.builder()
                .username(request.getUsername())
                .email(request.getEmail())
                .password(passwordEncoder.encode(request.getPassword()))
                .fullName(request.getFullName())
                .badgeNumber(assignedBadgeNumber)
                .role(assignedRole)
                .assignedPark(request.getAssignedPark())
                .phoneNumber(request.getPhoneNumber())
                .active(true)
                .build();

        User savedUser = userRepository.save(user);
        log.info("Successfully registered user '{}' with role '{}'", savedUser.getUsername(), savedUser.getRole());

        String token = tokenProvider.generateTokenForUser(savedUser.getUsername(), savedUser.getRole().name());

        return AuthResponse.builder()
                .token(token)
                .expiresIn(tokenProvider.getExpirationMs())
                .userId(savedUser.getId())
                .username(savedUser.getUsername())
                .email(savedUser.getEmail())
                .fullName(savedUser.getFullName())
                .role(savedUser.getRole())
                .badgeNumber(savedUser.getBadgeNumber())
                .assignedPark(savedUser.getAssignedPark())
                .phoneNumber(savedUser.getPhoneNumber())
                .build();
    }

    @Override
    public AuthResponse login(LoginRequest request) {
        log.info("Authenticating user: {}", request.getUsername());

        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getUsername(), request.getPassword())
        );

        String token = tokenProvider.generateToken(authentication);
        User user = userRepository.findByUsername(request.getUsername())
                .orElseThrow(() -> new DuplicateResourceException("User not found after authentication"));

        log.info("User '{}' successfully authenticated", user.getUsername());

        return AuthResponse.builder()
                .token(token)
                .expiresIn(tokenProvider.getExpirationMs())
                .userId(user.getId())
                .username(user.getUsername())
                .email(user.getEmail())
                .fullName(user.getFullName())
                .role(user.getRole())
                .badgeNumber(user.getBadgeNumber())
                .assignedPark(user.getAssignedPark())
                .phoneNumber(user.getPhoneNumber())
                .build();
    }

    @Override
    public String getNextBadgeNumber(Role role) {
        String prefix;
        switch (role) {
            case ROLE_MANAGER:
                prefix = "WG-MGR-";
                break;
            case ROLE_LIAISON:
                prefix = "WG-LIA-";
                break;
            case ROLE_VILLAGER:
                prefix = "WG-VIL-";
                break;
            case ROLE_RANGER:
            default:
                prefix = "WG-RNG-";
                break;
        }

        long count = userRepository.countByRole(role);
        int seq = (int) count + 1;
        String candidate = String.format("%s%03d", prefix, seq);
        while (userRepository.existsByBadgeNumber(candidate) ||
               (role == Role.ROLE_RANGER && userRepository.existsByBadgeNumber(String.format("WG-%03d", seq)))) {
            seq++;
            candidate = String.format("%s%03d", prefix, seq);
        }
        return candidate;
    }

    private String resolveOrGenerateBadgeNumber(String requestedBadge, Role role) {
        if (requestedBadge != null && !requestedBadge.isBlank() && !userRepository.existsByBadgeNumber(requestedBadge)) {
            return requestedBadge;
        }
        return getNextBadgeNumber(role);
    }
}
