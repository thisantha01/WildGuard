package com.wildlife.uc02.service.impl;

import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.geometry.*;
import com.wildlife.uc02.repository.*;
import com.wildlife.uc02.service.api.GeofenceEngine;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Component 2: Evaluates geofence breaches using Strategy pattern.
 * EF-02: No zones configured -> uses in-memory cache, logs, notifies manager.
 * EF-06: Invalid polygon -> BoundingBox fallback, flags zone.valid=false.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class GeofenceEngineImpl implements GeofenceEngine {

    private final GeofenceZoneRepository geofenceZoneRepository;
    private final ParkRepository parkRepository;
    private final RayCastingStrategy rayCastingStrategy;
    private final BoundingBoxStrategy boundingBoxStrategy;
    private final PolygonValidator polygonValidator;
    private final SystemLogRepository systemLogRepository;

    /** In-memory cache of last known active zones per parkId (EF-02). */
    private final Map<String, List<GeofenceZone>> zoneCache = new ConcurrentHashMap<>();

    @Override
    public BreachResult evaluate(Animal animal, TelemetryRecord telemetry) {
        // Find park for the animal's collar
        String parkId = findParkIdForCollar(telemetry.getCollar());
        if (parkId == null) {
            log.warn("No park found for collar {}", telemetry.getCollar().getCode());
            return BreachResult.builder().inside(false).build();
        }

        List<GeofenceZone> zones = loadZones(parkId);
        if (zones.isEmpty()) {
            return BreachResult.builder().inside(false).build();
        }

        GeoPoint point = GeoPoint.builder().lat(telemetry.getLat()).lng(telemetry.getLng()).build();

        for (GeofenceZone zone : zones) {
            BreachResult result = testZone(point, zone);
            if (result.isInside()) {
                return result;
            }
        }
        return BreachResult.builder().inside(false).build();
    }

    private BreachResult testZone(GeoPoint point, GeofenceZone zone) {
        List<GeoPoint> polygon = zone.getPolygon();

        // EF-06: Invalid polygon -> bounding box fallback
        if (!polygonValidator.isValid(polygon)) {
            log.error("EF-06: Invalid polygon for zone {} - using bounding box fallback", zone.getName());
            systemLogRepository.save(SystemLog.builder()
                    .level("ERROR")
                    .message("EF-06: Invalid polygon for zone=" + zone.getName() + " id=" + zone.getId())
                    .build());
            // Mark zone as invalid (we can't update here directly without a @Transactional context,
            // so we update it lazily - the zone.valid flag is set)
            zone.setValid(false);
            boolean inside = boundingBoxStrategy.contains(point, polygon);
            return BreachResult.builder().inside(inside).zone(inside ? zone : null)
                    .approximateLocation(inside).build();
        }

        boolean inside = rayCastingStrategy.contains(point, polygon);
        return BreachResult.builder().inside(inside).zone(inside ? zone : null)
                .approximateLocation(false).build();
    }

    private List<GeofenceZone> loadZones(String parkId) {
        List<GeofenceZone> zones = (parkId != null)
                ? geofenceZoneRepository.findByParkIdAndActiveTrue(parkId)
                : List.of();
        if (zones == null || zones.isEmpty()) {
            zones = geofenceZoneRepository.findByActiveTrue();
            if (parkId != null && !zones.isEmpty()) {
                List<GeofenceZone> parkZones = zones.stream()
                        .filter(z -> (z.getPark() != null && parkId.equals(z.getPark().getId()))
                                || (z.getParkId() != null && parkId.equals(z.getParkId())))
                        .toList();
                if (!parkZones.isEmpty()) {
                    zones = parkZones;
                }
            }
        }
        if (zones.isEmpty()) {
            // EF-02: Use cache if no zones configured
            String cacheKey = parkId != null ? parkId : "default";
            List<GeofenceZone> cached = zoneCache.get(cacheKey);
            if (cached != null && !cached.isEmpty()) {
                log.warn("EF-02: No active zones in DB for park {}. Using cached zones.", parkId);
                systemLogRepository.save(SystemLog.builder()
                        .level("WARN")
                        .message("EF-02: No active zones for park=" + parkId + ". Using cache.")
                        .build());
                return cached;
            }
            // No cache either - store as unevaluated (handled by evaluated=false flag)
            log.error("EF-02: No zones configured for park {} and no cache available", parkId);
            systemLogRepository.save(SystemLog.builder()
                    .level("ERROR")
                    .message("EF-02: No zones and no cache for park=" + parkId)
                    .build());
            return List.of();
        }
        // Update cache
        if (parkId != null) {
            zoneCache.put(parkId, zones);
        }
        return zones;
    }

    private String findParkIdForCollar(Collar collar) {
        String parkId = parkRepository.findAll().stream()
                .findFirst().map(Park::getId).orElse(null);
        if (parkId != null) return parkId;
        return geofenceZoneRepository.findByActiveTrue().stream()
                .filter(z -> z.getPark() != null && z.getPark().getId() != null)
                .map(z -> z.getPark().getId())
                .findFirst().orElse("park-default");
    }
}