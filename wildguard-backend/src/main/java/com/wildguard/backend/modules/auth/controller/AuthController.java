package com.wildguard.backend.modules.auth.controller;

import com.wildguard.backend.modules.auth.dto.AuthResponse;
import com.wildguard.backend.modules.auth.dto.LoginRequest;
import com.wildguard.backend.modules.auth.dto.RegisterRequest;
import com.wildguard.backend.modules.auth.service.AuthService;
import com.wildguard.backend.modules.user.model.Role;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        log.info("Received registration request for username: {}", request.getUsername());
        AuthResponse response = authService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        log.info("Received login request for username: {}", request.getUsername());
        AuthResponse response = authService.login(request);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/next-badge")
    public ResponseEntity<Map<String, String>> getNextBadgeNumber(
            @RequestParam(name = "role", defaultValue = "RANGER") String role) {
        log.info("Request for next badge number for role: {}", role);
        Role userRole = Role.fromString(role);
        String nextBadge = authService.getNextBadgeNumber(userRole);
        return ResponseEntity.ok(Map.of("badgeNumber", nextBadge));
    }
}
