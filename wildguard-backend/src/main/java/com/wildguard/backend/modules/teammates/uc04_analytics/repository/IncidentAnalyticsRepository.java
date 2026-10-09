package com.wildguard.backend.modules.teammates.uc04_analytics.repository;

import com.wildguard.backend.modules.incident.model.Incident;
import com.wildguard.backend.modules.incident.model.IncidentSeverity;
import com.wildguard.backend.modules.incident.model.IncidentType;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;

/**
 * UC04 read-only data access for the existing "incidents" collection.
 * It only READS incidents (never writes) and never touches the incident module's code.
 * The heavy photoBase64 field is excluded because analytics never needs it.
 */
@Repository
@RequiredArgsConstructor
public class IncidentAnalyticsRepository {

    private final MongoTemplate mongoTemplate;

    public List<Incident> find(Instant from, Instant to, IncidentType type,
                               IncidentSeverity severity, String rangerUsername) {
        Criteria criteria = Criteria.where("timestamp").gte(from).lt(to);
        if (type != null) {
            criteria = criteria.and("type").is(type);
        }
        if (severity != null) {
            criteria = criteria.and("severity").is(severity);
        }
        if (rangerUsername != null && !rangerUsername.isBlank()) {
            criteria = criteria.and("rangerUsername").is(rangerUsername);
        }
        Query query = new Query(criteria).with(Sort.by(Sort.Direction.ASC, "timestamp"));
        query.fields().exclude("photoBase64");
        return mongoTemplate.find(query, Incident.class);
    }

    public long count(Instant from, Instant to, IncidentType type,
                      IncidentSeverity severity, String rangerUsername) {
        Criteria criteria = Criteria.where("timestamp").gte(from).lt(to);
        if (type != null) {
            criteria = criteria.and("type").is(type);
        }
        if (severity != null) {
            criteria = criteria.and("severity").is(severity);
        }
        if (rangerUsername != null && !rangerUsername.isBlank()) {
            criteria = criteria.and("rangerUsername").is(rangerUsername);
        }
        return mongoTemplate.count(new Query(criteria), Incident.class);
    }
}
