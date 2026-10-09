package com.wildlife.uc02.dto;
import lombok.*;
@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class SyncActionResult {
    private String clientActionId;
    private String status; // APPLIED|DUPLICATE|REJECTED
    private String reason;
}