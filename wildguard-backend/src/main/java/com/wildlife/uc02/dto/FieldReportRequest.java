package com.wildlife.uc02.dto;
import com.wildlife.uc02.entity.CropDamage;
import com.wildlife.uc02.entity.InjurySeverity;
import jakarta.validation.constraints.NotNull;
import lombok.*;
@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class FieldReportRequest {
    @NotNull private CropDamage cropDamage;
    @NotNull private InjurySeverity injuries;
    @NotNull private Boolean situationSafe;
    private String notes;
}