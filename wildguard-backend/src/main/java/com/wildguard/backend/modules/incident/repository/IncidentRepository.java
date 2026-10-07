package com.wildguard.backend.modules.incident.repository;

import com.wildguard.backend.modules.incident.model.Incident;
import com.wildguard.backend.modules.incident.model.IncidentType;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Repository
public interface IncidentRepository extends MongoRepository<Incident, String> {

    List<Incident> findByRangerIdOrderByTimestampDesc(String rangerId);

    List<Incident> findByRangerUsernameOrderByTimestampDesc(String rangerUsername);

    Optional<Incident> findByLocalIncidentIdAndRangerId(String localIncidentId, String rangerId);

    List<Incident> findByTypeAndTimestampBetween(IncidentType type, Instant start, Instant end);
}
