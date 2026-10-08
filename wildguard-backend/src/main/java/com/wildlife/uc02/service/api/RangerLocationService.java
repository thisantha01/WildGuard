package com.wildlife.uc02.service.api;
import com.wildlife.uc02.dto.LocationUpdateRequest;
import com.wildlife.uc02.entity.RangerStatus;
/** Manages ranger location and heartbeat updates. */
public interface RangerLocationService {
    RangerStatus updateLocation(String userId, LocationUpdateRequest request);
    void heartbeat(String userId);
}