package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

/**
 * UC02 extension for a ranger, linked to the existing User by userId.
 * Keeps UC02 ranger-specific fields (location, availability, unit)
 * without touching the existing User entity.
 */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_ranger_statuses")
public class RangerStatus {
    @Id  private String id;
    @Indexed(unique = true) private String userId;   // FK -> existing User._id
    private String name;
    private String unitCode;
    private String parkId;
    @Builder.Default private RangerAvailability availability = RangerAvailability.AVAILABLE;
    private Double lastLat;
    private Double lastLng;
    private Instant lastLocationAt;
}
