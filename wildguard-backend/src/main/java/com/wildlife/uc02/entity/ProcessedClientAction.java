package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

/** Idempotency record for offline ranger sync actions. */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_processed_client_actions")
public class ProcessedClientAction {
    @Id  private String id;
    @Indexed(unique = true) private String clientActionId;
    @Builder.Default private Instant processedAt = Instant.now();
}
