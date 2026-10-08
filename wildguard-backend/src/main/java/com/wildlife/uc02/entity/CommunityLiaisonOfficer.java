package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

/** A Community Liaison Officer (CLO) user extension for UC02. */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_clos")
public class CommunityLiaisonOfficer {
    @Id  private String id;
    @Indexed(unique = true) private String userId;
    private String name;
    private String parkId;
}
