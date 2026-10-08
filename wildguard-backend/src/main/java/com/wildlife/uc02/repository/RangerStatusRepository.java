package com.wildlife.uc02.repository;
import com.wildlife.uc02.entity.RangerAvailability;
import com.wildlife.uc02.entity.RangerStatus;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;
@Repository
public interface RangerStatusRepository extends MongoRepository<RangerStatus, String> {
    Optional<RangerStatus> findByUserId(String userId);
    List<RangerStatus> findByParkIdAndAvailability(String parkId, RangerAvailability availability);
    List<RangerStatus> findByParkId(String parkId);
}
