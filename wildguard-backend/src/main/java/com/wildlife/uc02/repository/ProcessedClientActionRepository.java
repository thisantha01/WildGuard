package com.wildlife.uc02.repository;
import com.wildlife.uc02.entity.ProcessedClientAction;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
@Repository
public interface ProcessedClientActionRepository extends MongoRepository<ProcessedClientAction, String> {
    boolean existsByClientActionId(String clientActionId);
}
