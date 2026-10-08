package com.wildlife.uc02.service.api;

import com.wildlife.uc02.entity.Alert;
import com.wildlife.uc02.entity.AlertStatus;
import com.wildlife.uc02.entity.Animal;
import com.wildlife.uc02.entity.GeofenceZone;
import com.wildlife.uc02.entity.TelemetryRecord;
import com.wildlife.uc02.dto.FieldReportRequest;

/** Orchestrates alert lifecycle: creation, dispatch, ranger actions, and re-entry. */
public interface AlertManager {
    void handleBreach(Animal animal, GeofenceZone zone, TelemetryRecord telemetry);
    void handleNonBreach(Animal animal, TelemetryRecord telemetry);
    void acknowledge(String alertId, String rangerId);
    void decline(String alertId, String rangerId, String reason);
    void confirmDispatch(String alertId, String rangerId);
    void arrived(String alertId, String rangerId);
    void submitFieldReport(String alertId, String rangerId, FieldReportRequest request);
    void transitionAlert(Alert alert, AlertStatus toStatus, String changedBy, String note);
}