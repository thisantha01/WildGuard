package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

/** Structured system log entry for EF-01, EF-02, EF-06 error tracking. */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_system_logs")
public class SystemLog {
    @Id  private String id;
    private String level;
    private String message;
    @Builder.Default private Instant createdAt = Instant.now();
}
