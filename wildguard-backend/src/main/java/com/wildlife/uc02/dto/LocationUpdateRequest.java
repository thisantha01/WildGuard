package com.wildlife.uc02.dto;
import com.wildlife.uc02.entity.RangerAvailability;
import jakarta.validation.constraints.*;
import lombok.*;
@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class LocationUpdateRequest {
    @DecimalMin("-90.0") @DecimalMax("90.0") private double lat;
    @DecimalMin("-180.0") @DecimalMax("180.0") private double lng;
    private RangerAvailability availability;
}