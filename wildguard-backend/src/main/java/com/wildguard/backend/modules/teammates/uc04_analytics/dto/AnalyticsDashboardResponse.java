package com.wildguard.backend.modules.teammates.uc04_analytics.dto;

import java.util.List;

/**
 * Full analytics payload consumed by the WildGuard manager dashboard.
 * Dates are ISO-8601 strings to keep the JSON contract independent of the Jackson version.
 */
public record AnalyticsDashboardResponse(
        String from,
        String to,
        String timezone,
        String generatedAt,
        Summary summary,
        List<CountItem> byType,
        List<CountItem> bySeverity,
        List<CountItem> bySyncStatus,
        List<TrendPoint> dailyTrend,
        List<CountItem> byHourOfDay,
        List<CountItem> byDayOfWeek,
        List<Hotspot> hotspots,
        List<RangerActivity> rangerActivity,
        List<String> insights) {

    public record Summary(
            long totalIncidents,
            long previousPeriodIncidents,
            Double changePercent,
            long criticalIncidents,
            long highIncidents,
            double criticalSharePercent,
            long duplicateFlagged,
            double duplicateRatePercent,
            long activeRangers,
            double avgIncidentsPerDay,
            double avgSeverityScore,
            String mostCommonType,
            String busiestHour) {}

    public record CountItem(String label, long count) {}

    public record TrendPoint(String date, long total, long critical) {}

    public record Hotspot(
            double latitude,
            double longitude,
            long count,
            long criticalCount,
            double avgSeverityScore,
            String dominantType) {}

    public record RangerActivity(
            String rangerUsername,
            long incidents,
            long criticalIncidents,
            String lastReportAt) {}
}
