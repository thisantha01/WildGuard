package com.wildguard.backend.modules.teammates.uc03_community;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.HashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class CommunityReportServiceImpl implements CommunityReportService {
    private final CommunityRecordRepository repository;
    @Override public List<Map<String,Object>> reports(String username, boolean liaison) {
        var records = liaison ? repository.findByKindOrderByIdDesc("REPORT") : repository.findByKindAndReporterUsernameOrderByIdDesc("REPORT", username);
        return records.stream().map(CommunityRecord::getPayload).toList();
    }
    @Override public List<Map<String,Object>> alerts() { return repository.findByKindOrderByIdDesc("ALERT").stream().map(CommunityRecord::getPayload).toList(); }
    @Override public Map<String,Object> saveReport(Map<String,Object> payload, String username) {
        String id = String.valueOf(payload.getOrDefault("id", ""));
        if(id.isBlank()) throw new IllegalArgumentException("Report id is required");
        var record = repository.findById(id).orElseGet(CommunityRecord::new);
        if (record.getPayload() != null) {
            var mergedPayload = new HashMap<>(record.getPayload());
            mergedPayload.putAll(payload);
            payload = mergedPayload;
        }
        record.setId(id); record.setKind("REPORT");
        boolean newReport = record.getReporterUsername() == null;
        if (newReport) record.setReporterUsername(username);
        if ("PENDING_SYNC".equals(payload.get("status"))) payload.put("status", "UNVERIFIED");
        record.setPayload(payload);
        return repository.save(record).getPayload();
    }
    @Override public Map<String,Object> saveAlert(Map<String,Object> payload) {
        String id = String.valueOf(payload.getOrDefault("id", ""));
        if(id.isBlank()) throw new IllegalArgumentException("Alert id is required");
        var record = repository.findById(id).orElseGet(CommunityRecord::new);
        record.setId(id); record.setKind("ALERT"); record.setPayload(payload);
        return repository.save(record).getPayload();
    }
}
