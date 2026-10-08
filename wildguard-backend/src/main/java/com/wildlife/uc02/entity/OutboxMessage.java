package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

/** Outbox entry for reliable notification delivery with retry semantics. */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_outbox_messages")
public class OutboxMessage {
    @Id private String id;
    private String alertId;
    private NotificationChannel channel;
    private String recipient;
    private String payload;
    @Builder.Default private int attempts = 0;
    private Instant nextAttemptAt;
    @Builder.Default private Instant createdAt = Instant.now();
    @Builder.Default private OutboxStatus status = OutboxStatus.PENDING;
}
