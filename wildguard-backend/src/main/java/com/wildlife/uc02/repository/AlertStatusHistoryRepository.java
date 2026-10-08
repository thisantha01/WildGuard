package com.wildlife.uc02.repository;
import com.wildlife.uc02.entity.AlertStatusHistory;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
@Repository
public interface AlertStatusHistoryRepository extends MongoRepository<AlertStatusHistory, String> {
    List<AlertStatusHistory> findByAlertIdOrderByChangedAtAsc(String alertId);
}
