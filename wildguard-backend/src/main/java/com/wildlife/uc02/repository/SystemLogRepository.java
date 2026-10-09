package com.wildlife.uc02.repository;
import com.wildlife.uc02.entity.SystemLog;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
@Repository
public interface SystemLogRepository extends MongoRepository<SystemLog, String> {}
