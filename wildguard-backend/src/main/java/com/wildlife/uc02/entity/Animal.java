package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * Represents a tracked animal in the wildlife conservation system.
 * Seed: Rajah / ELE-024 / Sri Lankan elephant / male.
 */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_animals")
public class Animal {
    @Id  private String id;
    private String name;
    @Indexed(unique = true) private String tagId;
    private String species;
    private String sex;
}
