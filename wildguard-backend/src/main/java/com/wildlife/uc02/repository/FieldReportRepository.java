package com.wildlife.uc02.repository;
import com.wildlife.uc02.entity.FieldReport;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;
@Repository
public interface FieldReportRepository extends MongoRepository<FieldReport, String> {
    Optional<FieldReport> findByAlertId(String alertId);
}
