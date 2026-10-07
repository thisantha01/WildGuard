package com.wildguard.backend.modules.incident.dto;

import com.wildguard.backend.modules.incident.model.IncidentSeverity;
import com.wildguard.backend.modules.incident.model.IncidentType;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class IncidentSyncRequest {

    @NotBlank(message = "Local incident ID is required")
    private String localIncidentId;

    @NotNull(message = "Incident type is required")
    private IncidentType type;

    @NotNull(message = "Incident severity is required")
    private IncidentSeverity severity;

    @NotBlank(message = "Incident description is required")
    private String description;

    @NotNull(message = "Latitude is required")
    @DecimalMin(value = "-90.0", message = "Latitude must be greater than or equal to -90.0")
    @DecimalMax(value = "90.0", message = "Latitude must be less than or equal to 90.0")
    private Double latitude;

    @NotNull(message = "Longitude is required")
    @DecimalMin(value = "-180.0", message = "Longitude must be greater than or equal to -180.0")
    @DecimalMax(value = "180.0", message = "Longitude must be less than or equal to 180.0")
    private Double longitude;

    private String photoBase64;

    @NotNull(message = "Incident timestamp is required")
    private Instant timestamp;
}
