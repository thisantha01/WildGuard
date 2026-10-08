package com.wildlife.uc02.service.impl;

import com.wildlife.uc02.dto.LocationUpdateRequest;
import com.wildlife.uc02.entity.RangerStatus;
import com.wildlife.uc02.exception.RangerNotFoundException;
import com.wildlife.uc02.repository.RangerStatusRepository;
import com.wildlife.uc02.service.api.RangerLocationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;

@Slf4j
@Service
@RequiredArgsConstructor
public class RangerLocationServiceImpl implements RangerLocationService {
    private final RangerStatusRepository rangerStatusRepository;
    private final Clock clock;

    @Override
    @Transactional
    public RangerStatus updateLocation(String userId, LocationUpdateRequest request) {
        RangerStatus rs = rangerStatusRepository.findByUserId(userId)
                .orElseThrow(() -> new RangerNotFoundException("Ranger not found: " + userId));
        rs.setLastLat(request.getLat());
        rs.setLastLng(request.getLng());
        rs.setLastLocationAt(Instant.now(clock));
        if (request.getAvailability() != null) {
            rs.setAvailability(request.getAvailability());
        }
        return rangerStatusRepository.save(rs);
    }

    @Override
    @Transactional
    public void heartbeat(String userId) {
        rangerStatusRepository.findByUserId(userId).ifPresent(rs -> {
            rs.setLastLocationAt(Instant.now(clock));
            rangerStatusRepository.save(rs);
            log.debug("Heartbeat received from ranger {}", userId);
        });
    }
}