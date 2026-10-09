package com.wildlife.uc02.dto;
import jakarta.validation.constraints.*;
import lombok.*;
import java.time.Instant;
@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class TelemetryRequest {
    @NotBlank(message = "collarCode is required") private String collarCode;
    @NotNull(message = "timestamp is required") private Instant timestamp;
    @DecimalMin("-90.0") @DecimalMax("90.0") private double latitude;
    @DecimalMin("-180.0") @DecimalMax("180.0") private double longitude;
    @Min(0) @Max(100) private int batteryPercent;
    @NotBlank(message = "checksum is required") private String checksum;
}