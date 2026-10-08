package com.wildlife.uc02.service.api;
import com.wildlife.uc02.entity.Animal;
import com.wildlife.uc02.geometry.BreachResult;
import com.wildlife.uc02.entity.TelemetryRecord;
/** Evaluates whether an animal has breached a geofence zone. The engine ONLY decides; never creates alerts. */
public interface GeofenceEngine {
    BreachResult evaluate(Animal animal, TelemetryRecord telemetry);
}