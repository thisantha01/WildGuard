package com.wildlife.uc02.repository;
import com.wildlife.uc02.entity.GeofenceZone;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
@Repository
public interface GeofenceZoneRepository extends MongoRepository<GeofenceZone, String> {
    List<GeofenceZone> findByParkIdAndActiveTrue(String parkId);
    List<GeofenceZone> findByActiveTrue();
}
