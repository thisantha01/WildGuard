package com.wildlife.uc02.repository;

import com.wildlife.uc02.entity.Collar;
import com.wildlife.uc02.entity.CollarStatus;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Repository
public interface CollarRepository extends MongoRepository<Collar, String> {
    Optional<Collar> findByCode(String code);
    List<Collar> findByLastPacketAtBeforeAndStatusNot(Instant cutoff, CollarStatus status);
    Optional<Collar> findByAnimal_Id(String animalId);
    default Optional<Collar> findByAnimalId(String animalId) {
        return findByAnimal_Id(animalId);
    }
}
