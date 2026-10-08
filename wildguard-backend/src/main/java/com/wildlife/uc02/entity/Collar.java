package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;
import org.springframework.data.mongodb.core.mapping.DBRef;

import java.time.Instant;

/** IoT tracking collar attached to an animal. */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_collars")
public class Collar {
    @Id private String id;
    @Indexed(unique = true) private String code;
    @DBRef private Animal animal;
    @Builder.Default private int batteryPercent = 100;
    private Instant lastPacketAt;
    @Builder.Default private CollarStatus status = CollarStatus.ACTIVE;
}
