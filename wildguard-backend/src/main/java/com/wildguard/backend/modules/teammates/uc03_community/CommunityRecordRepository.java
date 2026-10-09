package com.wildguard.backend.modules.teammates.uc03_community;

import org.springframework.data.mongodb.repository.MongoRepository;
import java.util.List;

public interface CommunityRecordRepository extends MongoRepository<CommunityRecord, String> {
    List<CommunityRecord> findByKindOrderByIdDesc(String kind);
    List<CommunityRecord> findByKindAndReporterUsernameOrderByIdDesc(String kind, String reporterUsername);
}
