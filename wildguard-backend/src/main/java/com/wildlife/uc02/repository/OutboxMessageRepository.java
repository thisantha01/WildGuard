package com.wildlife.uc02.repository;
import com.wildlife.uc02.entity.OutboxMessage;
import com.wildlife.uc02.entity.OutboxStatus;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
import java.time.Instant;
import java.util.List;
@Repository
public interface OutboxMessageRepository extends MongoRepository<OutboxMessage, String> {
    List<OutboxMessage> findByStatusAndNextAttemptAtBefore(OutboxStatus status, Instant now);
    List<OutboxMessage> findByAlertId(String alertId);
}
