package com.wildlife.uc02.dto;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import lombok.*;
import java.util.List;
@Data @NoArgsConstructor @AllArgsConstructor
public class SyncBatchRequest {
    @NotEmpty @Valid private List<SyncActionRequest> actions;
}