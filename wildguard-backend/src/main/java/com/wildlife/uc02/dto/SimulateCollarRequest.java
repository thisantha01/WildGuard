package com.wildlife.uc02.dto;
import jakarta.validation.constraints.NotBlank;
import lombok.*;
@Data @NoArgsConstructor @AllArgsConstructor
public class SimulateCollarRequest {
    @NotBlank private String animalTag;
    @NotBlank private String scenario;
}