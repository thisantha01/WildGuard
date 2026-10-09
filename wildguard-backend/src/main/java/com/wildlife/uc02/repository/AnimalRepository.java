package com.wildlife.uc02.repository;
import com.wildlife.uc02.entity.Animal;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;
@Repository
public interface AnimalRepository extends MongoRepository<Animal, String> {
    Optional<Animal> findByTagId(String tagId);
}
