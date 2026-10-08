package com.wildlife.uc02.repository;
import com.wildlife.uc02.entity.Park;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;
@Repository
public interface ParkRepository extends MongoRepository<Park, String> {
    Optional<Park> findByName(String name);
}
