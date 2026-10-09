package com.wildlife.uc02.dto;
import lombok.*;
import java.util.List;
@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class SyncBatchResponse {
    private List<SyncActionResult> results;
    private int applied;
    private int duplicates;
    private int rejected;
}