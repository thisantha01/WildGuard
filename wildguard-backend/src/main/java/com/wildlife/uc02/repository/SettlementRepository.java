package com.wildlife.uc02.repository;
import com.wildlife.uc02.entity.Settlement;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
@Repository
public interface SettlementRepository extends MongoRepository<Settlement, String> {
    List<Settlement> findByParkId(String parkId);
}
