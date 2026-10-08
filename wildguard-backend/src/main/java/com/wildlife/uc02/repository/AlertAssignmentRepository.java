package com.wildlife.uc02.repository;
import com.wildlife.uc02.entity.AlertAssignment;
import com.wildlife.uc02.entity.AssignmentOutcome;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;
@Repository
public interface AlertAssignmentRepository extends MongoRepository<AlertAssignment, String> {
    List<AlertAssignment> findByAlertId(String alertId);
    Optional<AlertAssignment> findByAlertIdAndRangerId(String alertId, String rangerId);
    List<AlertAssignment> findByAlertIdAndOutcomeIn(String alertId, List<AssignmentOutcome> outcomes);
}
