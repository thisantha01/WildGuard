package com.wildlife.uc02.service.api;
import com.wildlife.uc02.dto.TelemetryRequest;
import com.wildlife.uc02.entity.TelemetryRecord;
/** Validates, deduplicates, stores and routes telemetry packets from IoT collars. */
public interface TelemetryIngestionService {
    TelemetryRecord ingest(TelemetryRequest request);
}