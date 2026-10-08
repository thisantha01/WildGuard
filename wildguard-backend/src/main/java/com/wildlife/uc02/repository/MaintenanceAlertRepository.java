package com.wildlife.uc02.repository;
import com.wildlife.uc02.entity.MaintenanceAlert;
import com.wildlife.uc02.entity.MaintenanceAlertType;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;
@Repository
public interface MaintenanceAlertRepository extends MongoRepository<MaintenanceAlert, String> {
    Optional<MaintenanceAlert> findByCollarIdAndTypeAndResolvedFalse(String collarId, MaintenanceAlertType type);
    List<MaintenanceAlert> findByResolvedFalse();
}
