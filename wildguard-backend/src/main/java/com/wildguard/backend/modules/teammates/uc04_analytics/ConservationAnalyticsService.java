package com.wildguard.backend.modules.teammates.uc04_analytics;

import com.wildguard.backend.modules.teammates.uc04_analytics.dto.AnalyticsDashboardResponse;
import com.wildguard.backend.modules.incident.model.IncidentSeverity;
import com.wildguard.backend.modules.incident.model.IncidentType;

import java.time.LocalDate;

/**
 * UC04: Generate Conservation Analytics Reports.
 * Reads incident data (read-only) and turns it into dashboard analytics and exportable reports.
 */
public interface ConservationAnalyticsService {

    AnalyticsDashboardResponse getDashboard(LocalDate from, LocalDate to, String timezone,
                                            IncidentType type, IncidentSeverity severity,
                                            String rangerUsername);

    /** Raw incident report as CSV text (photos excluded). */
    String exportCsv(LocalDate from, LocalDate to, String timezone,
                     IncidentType type, IncidentSeverity severity, String rangerUsername);
}
