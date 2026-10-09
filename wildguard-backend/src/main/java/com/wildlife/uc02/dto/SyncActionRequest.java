package com.wildlife.uc02.dto;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.*;
import java.time.Instant;
import java.util.Map;
@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class SyncActionRequest {
    @NotBlank private String clientActionId;
    @NotBlank private String type; // ACKNOWLEDGE|DECLINE|CONFIRM_DISPATCH|FIELD_REPORT|LOCATION_UPDATE
    private String alertId;
    @NotNull private Instant occurredAt;
    private Map<String, Object> payload;
}