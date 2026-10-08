package com.wildguard.backend.modules.teammates.uc03_community;

import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;
import java.util.Map;

@Data
@Document(collection = "community_records")
public class CommunityRecord {
    @Id private String id;
    @Indexed private String kind;
    @Indexed private String reporterUsername;
    private Map<String, Object> payload;
}
