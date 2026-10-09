package com.wildlife.uc02.repository;
import com.wildlife.uc02.entity.TelemetryRecord;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
@Repository
public interface TelemetryRecordRepository extends MongoRepository<TelemetryRecord, String> {
    Optional<TelemetryRecord> findByCollarIdAndTimestamp(String collarId, Instant timestamp);
    List<TelemetryRecord> findByAnimalIdAndEvaluatedFalseOrderByTimestampAsc(String animalId);
    List<TelemetryRecord> findByAnimalIdOrderByTimestampDesc(String animalId);
    List<TelemetryRecord> findTop5ByAnimalIdOrderByTimestampDesc(String animalId);
}
