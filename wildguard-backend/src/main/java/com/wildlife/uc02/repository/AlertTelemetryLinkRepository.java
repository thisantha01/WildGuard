package com.wildlife.uc02.repository;
import com.wildlife.uc02.entity.AlertTelemetryLink;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
@Repository
public interface AlertTelemetryLinkRepository extends MongoRepository<AlertTelemetryLink, String> {
    List<AlertTelemetryLink> findByAlertId(String alertId);
}
