package com.wildguard.backend.modules.user.controller;

import com.wildguard.backend.modules.user.dto.RangerProfileResponse;
import com.wildguard.backend.modules.user.service.UserService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.security.Principal;

@Slf4j
@RestController
@RequestMapping("/api/rangers")
@RequiredArgsConstructor
public class RangerController {

    private final UserService userService;

    @GetMapping("/me")
    @PreAuthorize("hasRole('RANGER')")
    public ResponseEntity<RangerProfileResponse> getCurrentRangerProfile(Principal principal) {
        log.info("Request for current ranger profile by user: {}", principal.getName());
        RangerProfileResponse profile = userService.getRangerProfile(principal.getName());
        return ResponseEntity.ok(profile);
    }
}
