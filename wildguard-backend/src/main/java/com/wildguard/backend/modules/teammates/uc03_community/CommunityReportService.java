package com.wildguard.backend.modules.teammates.uc03_community;

import java.util.List;
import java.util.Map;

public interface CommunityReportService {
    List<Map<String, Object>> reports(String username, boolean liaison);
    List<Map<String, Object>> alerts();
    Map<String, Object> saveReport(Map<String, Object> payload, String username);
    Map<String, Object> saveAlert(Map<String, Object> payload);
}
