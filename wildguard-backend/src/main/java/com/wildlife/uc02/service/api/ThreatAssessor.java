package com.wildlife.uc02.service.api;
import com.wildlife.uc02.entity.Animal;
import com.wildlife.uc02.entity.GeofenceZone;
import com.wildlife.uc02.entity.TelemetryRecord;
import com.wildlife.uc02.entity.ThreatLevel;
/** Pure strategy for computing threat level - stateless, pure function, easy to unit test. */
public interface ThreatAssessor {
    ThreatLevel assess(Animal animal, GeofenceZone zone, TelemetryRecord telemetry, String parkId);
}