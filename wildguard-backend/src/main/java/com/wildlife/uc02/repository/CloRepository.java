package com.wildlife.uc02.repository;
import com.wildlife.uc02.entity.CommunityLiaisonOfficer;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;
@Repository
public interface CloRepository extends MongoRepository<CommunityLiaisonOfficer, String> {
    Optional<CommunityLiaisonOfficer> findByUserId(String userId);
    List<CommunityLiaisonOfficer> findByParkId(String parkId);
}
