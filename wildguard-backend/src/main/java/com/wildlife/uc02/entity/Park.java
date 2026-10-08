package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

/** Park entity - maps to uc02_parks MongoDB collection. */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_parks")
public class Park {
    @Id private String id;
    private String name;
    @Builder.Default private ParkConfig config = new ParkConfig();
}
