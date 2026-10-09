package com.wildlife.uc02.dto;
import jakarta.validation.constraints.NotBlank;
import lombok.*;
@Data @NoArgsConstructor @AllArgsConstructor
public class AssignRangerRequest {
    @NotBlank private String rangerId;
}