package com.wildlife.uc02.repository;

import com.wildlife.uc02.entity.Alert;
import com.wildlife.uc02.entity.AlertStatus;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Repository
public interface AlertRepository extends MongoRepository<Alert, String> {
    Optional<Alert> findByDisplayCode(String displayCode);
    List<Alert> findByAnimalIdAndStatusNotIn(String animalId, List<AlertStatus> excludedStatuses);
    List<Alert> findByAssignedRangerIdAndStatus(String rangerId, AlertStatus status);
    List<Alert> findByAssignedRangerIdAndStatusIn(String rangerId, List<AlertStatus> statuses);
    List<Alert> findByAssignedRangerId(String rangerId);
    List<Alert> findByStatus(AlertStatus status);
    List<Alert> findByStatusIn(List<AlertStatus> statuses);
    List<Alert> findByParkIdAndStatusIn(String parkId, List<AlertStatus> statuses);
    long countByDisplayCodeStartingWith(String prefix);
    List<Alert> findByBreachTimeBetween(Instant start, Instant end);
}
