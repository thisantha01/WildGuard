package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.DBRef;
import org.springframework.data.mongodb.core.mapping.Document;

/** A human settlement used for distance-based threat assessment. */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_settlements")
public class Settlement {
    @Id  private String id;
    @DBRef private Park park;
    private String parkId;
    private String name;
    private double lat;
    private double lng;
}
