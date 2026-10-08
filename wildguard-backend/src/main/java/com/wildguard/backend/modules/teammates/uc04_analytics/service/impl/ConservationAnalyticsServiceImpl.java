package com.wildguard.backend.modules.teammates.uc04_analytics.service.impl;

import com.wildguard.backend.modules.teammates.uc04_analytics.ConservationAnalyticsService;
import com.wildguard.backend.modules.teammates.uc04_analytics.dto.AnalyticsDashboardResponse;
import com.wildguard.backend.modules.teammates.uc04_analytics.dto.AnalyticsDashboardResponse.CountItem;
import com.wildguard.backend.modules.teammates.uc04_analytics.dto.AnalyticsDashboardResponse.Hotspot;
import com.wildguard.backend.modules.teammates.uc04_analytics.dto.AnalyticsDashboardResponse.RangerActivity;
import com.wildguard.backend.modules.teammates.uc04_analytics.dto.AnalyticsDashboardResponse.Summary;
import com.wildguard.backend.modules.teammates.uc04_analytics.dto.AnalyticsDashboardResponse.TrendPoint;
import com.wildguard.backend.modules.teammates.uc04_analytics.repository.IncidentAnalyticsRepository;
import com.wildguard.backend.common.exception.ValidationException;
import com.wildguard.backend.modules.incident.model.Incident;
import com.wildguard.backend.modules.incident.model.IncidentSeverity;
import com.wildguard.backend.modules.incident.model.IncidentType;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.DateTimeException;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.temporal.ChronoUnit;
import java.time.format.TextStyle;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class ConservationAnalyticsServiceImpl implements ConservationAnalyticsService {

    private static final int DEFAULT_RANGE_DAYS = 30;
    private static final int MAX_RANGE_DAYS = 366;
    private static final int MAX_HOTSPOTS = 10;
    /** Rounding to 2 decimal places groups reports into ~1.1 km grid cells. */
    private static final double GRID_SCALE = 100.0;

    private final IncidentAnalyticsRepository repository;

    @Override
    public AnalyticsDashboardResponse getDashboard(LocalDate from, LocalDate to, String timezone,
                                                   IncidentType type, IncidentSeverity severity,
                                                   String rangerUsername) {
        ZoneId zone = resolveZone(timezone);
        LocalDate end = to != null ? to : LocalDate.now(zone);
        LocalDate start = from != null ? from : end.minusDays(DEFAULT_RANGE_DAYS - 1L);
        validateRange(start, end);

        Instant fromInstant = start.atStartOfDay(zone).toInstant();
        Instant toInstant = end.plusDays(1).atStartOfDay(zone).toInstant();

        long days = ChronoUnit.DAYS.between(start, end) + 1;
        Instant prevFrom = start.minusDays(days).atStartOfDay(zone).toInstant();

        List<Incident> incidents = repository.find(fromInstant, toInstant, type, severity, rangerUsername);
        long previousCount = repository.count(prevFrom, fromInstant, type, severity, rangerUsername);
        log.info("Analytics dashboard: {} incidents between {} and {} (previous period: {})",
                incidents.size(), start, end, previousCount);

        List<CountItem> byType = countBy(incidents, i -> i.getType() == null ? "UNKNOWN" : i.getType().name());
        List<CountItem> bySeverity = orderedSeverity(incidents);
        List<CountItem> bySync = countBy(incidents, i -> i.getSyncStatus() == null ? "UNKNOWN" : i.getSyncStatus().name());
        List<TrendPoint> trend = dailyTrend(incidents, start, end, zone);
        List<CountItem> byHour = hourOfDay(incidents, zone);
        List<CountItem> byDow = dayOfWeek(incidents, zone);
        List<Hotspot> hotspots = hotspots(incidents);
        List<RangerActivity> rangers = rangerActivity(incidents);

        Summary summary = buildSummary(incidents, previousCount, days, byType, byHour);
        List<String> insights = buildInsights(summary, hotspots, byType);

        return new AnalyticsDashboardResponse(
                start.toString(), end.toString(), zone.getId(), Instant.now().toString(),
                summary, byType, bySeverity, bySync, trend, byHour, byDow, hotspots, rangers, insights);
    }

    @Override
    public String exportCsv(LocalDate from, LocalDate to, String timezone,
                            IncidentType type, IncidentSeverity severity, String rangerUsername) {
        ZoneId zone = resolveZone(timezone);
        LocalDate end = to != null ? to : LocalDate.now(zone);
        LocalDate start = from != null ? from : end.minusDays(DEFAULT_RANGE_DAYS - 1L);
        validateRange(start, end);

        List<Incident> incidents = repository.find(
                start.atStartOfDay(zone).toInstant(),
                end.plusDays(1).atStartOfDay(zone).toInstant(),
                type, severity, rangerUsername);

        StringBuilder sb = new StringBuilder(
                "id,timestamp,type,severity,ranger,latitude,longitude,duplicate,syncStatus,description\n");
        for (Incident i : incidents) {
            sb.append(csv(i.getId())).append(',')
              .append(csv(i.getTimestamp() == null ? "" : i.getTimestamp().toString())).append(',')
              .append(csv(i.getType() == null ? "" : i.getType().name())).append(',')
              .append(csv(i.getSeverity() == null ? "" : i.getSeverity().name())).append(',')
              .append(csv(i.getRangerUsername())).append(',')
              .append(i.getLocation() == null || i.getLocation().getLatitude() == null ? "" : i.getLocation().getLatitude()).append(',')
              .append(i.getLocation() == null || i.getLocation().getLongitude() == null ? "" : i.getLocation().getLongitude()).append(',')
              .append(i.isDuplicateFlag()).append(',')
              .append(csv(i.getSyncStatus() == null ? "" : i.getSyncStatus().name())).append(',')
              .append(csv(i.getDescription())).append('\n');
        }
        return sb.toString();
    }

    // ---------------------------------------------------------------- helpers

    private ZoneId resolveZone(String timezone) {
        if (timezone == null || timezone.isBlank()) {
            return ZoneId.of("UTC");
        }
        try {
            return ZoneId.of(timezone);
        } catch (DateTimeException ex) {
            throw new ValidationException("Unknown timezone: " + timezone);
        }
    }

    private void validateRange(LocalDate start, LocalDate end) {
        if (end.isBefore(start)) {
            throw new ValidationException("'to' date must not be before 'from' date");
        }
        if (ChronoUnit.DAYS.between(start, end) + 1 > MAX_RANGE_DAYS) {
            throw new ValidationException("Date range cannot exceed " + MAX_RANGE_DAYS + " days");
        }
    }

    private static int score(IncidentSeverity s) {
        return s == null ? 0 : s.ordinal() + 1; // LOW=1 ... CRITICAL=4
    }

    private List<CountItem> countBy(List<Incident> incidents, java.util.function.Function<Incident, String> key) {
        return incidents.stream()
                .collect(Collectors.groupingBy(key, Collectors.counting()))
                .entrySet().stream()
                .map(e -> new CountItem(e.getKey(), e.getValue()))
                .sorted(Comparator.comparingLong(CountItem::count).reversed().thenComparing(CountItem::label))
                .toList();
    }

    private List<CountItem> orderedSeverity(List<Incident> incidents) {
        Map<IncidentSeverity, Long> counts = new EnumMap<>(IncidentSeverity.class);
        for (IncidentSeverity s : IncidentSeverity.values()) {
            counts.put(s, 0L);
        }
        incidents.stream().map(Incident::getSeverity).filter(Objects::nonNull)
                .forEach(s -> counts.merge(s, 1L, Long::sum));
        return counts.entrySet().stream().map(e -> new CountItem(e.getKey().name(), e.getValue())).toList();
    }

    private List<TrendPoint> dailyTrend(List<Incident> incidents, LocalDate start, LocalDate end, ZoneId zone) {
        Map<LocalDate, long[]> perDay = new HashMap<>();
        for (Incident i : incidents) {
            if (i.getTimestamp() == null) continue;
            LocalDate d = i.getTimestamp().atZone(zone).toLocalDate();
            long[] c = perDay.computeIfAbsent(d, k -> new long[2]);
            c[0]++;
            if (i.getSeverity() == IncidentSeverity.CRITICAL) c[1]++;
        }
        List<TrendPoint> out = new ArrayList<>();
        for (LocalDate d = start; !d.isAfter(end); d = d.plusDays(1)) {
            long[] c = perDay.getOrDefault(d, new long[2]);
            out.add(new TrendPoint(d.toString(), c[0], c[1]));
        }
        return out;
    }

    private List<CountItem> hourOfDay(List<Incident> incidents, ZoneId zone) {
        long[] hours = new long[24];
        incidents.stream().filter(i -> i.getTimestamp() != null)
                .forEach(i -> hours[i.getTimestamp().atZone(zone).getHour()]++);
        List<CountItem> out = new ArrayList<>();
        for (int h = 0; h < 24; h++) {
            out.add(new CountItem(String.format("%02d:00", h), hours[h]));
        }
        return out;
    }

    private List<CountItem> dayOfWeek(List<Incident> incidents, ZoneId zone) {
        long[] days = new long[7];
        incidents.stream().filter(i -> i.getTimestamp() != null)
                .forEach(i -> days[i.getTimestamp().atZone(zone).getDayOfWeek().getValue() - 1]++);
        List<CountItem> out = new ArrayList<>();
        for (DayOfWeek d : DayOfWeek.values()) {
            out.add(new CountItem(d.getDisplayName(TextStyle.SHORT, Locale.ENGLISH), days[d.getValue() - 1]));
        }
        return out;
    }

    private List<Hotspot> hotspots(List<Incident> incidents) {
        Map<String, List<Incident>> cells = incidents.stream()
                .filter(i -> i.getLocation() != null
                        && i.getLocation().getLatitude() != null
                        && i.getLocation().getLongitude() != null)
                .collect(Collectors.groupingBy(i ->
                        Math.round(i.getLocation().getLatitude() * GRID_SCALE) + ":"
                                + Math.round(i.getLocation().getLongitude() * GRID_SCALE)));

        return cells.entrySet().stream().map(e -> {
            List<Incident> list = e.getValue();
            double lat = list.stream().mapToDouble(i -> i.getLocation().getLatitude()).average().orElse(0);
            double lng = list.stream().mapToDouble(i -> i.getLocation().getLongitude()).average().orElse(0);
            long critical = list.stream().filter(i -> i.getSeverity() == IncidentSeverity.CRITICAL).count();
            double avg = list.stream().mapToInt(i -> score(i.getSeverity())).average().orElse(0);
            String dominant = list.stream().filter(i -> i.getType() != null)
                    .collect(Collectors.groupingBy(Incident::getType, Collectors.counting()))
                    .entrySet().stream().max(Map.Entry.comparingByValue())
                    .map(en -> en.getKey().name()).orElse("UNKNOWN");
            return new Hotspot(round(lat, 5), round(lng, 5), list.size(), critical, round(avg, 2), dominant);
        }).sorted(Comparator.comparingLong(Hotspot::count).reversed()
                .thenComparing(Comparator.comparingLong(Hotspot::criticalCount).reversed()))
          .limit(MAX_HOTSPOTS).toList();
    }

    private List<RangerActivity> rangerActivity(List<Incident> incidents) {
        return incidents.stream()
                .filter(i -> i.getRangerUsername() != null)
                .collect(Collectors.groupingBy(Incident::getRangerUsername))
                .entrySet().stream().map(e -> {
                    List<Incident> list = e.getValue();
                    long critical = list.stream().filter(i -> i.getSeverity() == IncidentSeverity.CRITICAL).count();
                    String last = list.stream().map(Incident::getTimestamp).filter(Objects::nonNull)
                            .max(Comparator.naturalOrder()).map(Instant::toString).orElse(null);
                    return new RangerActivity(e.getKey(), list.size(), critical, last);
                })
                .sorted(Comparator.comparingLong(RangerActivity::incidents).reversed())
                .limit(10).toList();
    }

    private Summary buildSummary(List<Incident> incidents, long previousCount, long days,
                                 List<CountItem> byType, List<CountItem> byHour) {
        long total = incidents.size();
        long critical = incidents.stream().filter(i -> i.getSeverity() == IncidentSeverity.CRITICAL).count();
        long high = incidents.stream().filter(i -> i.getSeverity() == IncidentSeverity.HIGH).count();
        long dup = incidents.stream().filter(Incident::isDuplicateFlag).count();
        long rangers = incidents.stream().map(Incident::getRangerUsername).filter(Objects::nonNull).distinct().count();
        double avgScore = incidents.stream().mapToInt(i -> score(i.getSeverity())).average().orElse(0);
        Double change = previousCount == 0 ? null : round((total - previousCount) * 100.0 / previousCount, 1);
        String topType = byType.isEmpty() ? null : byType.get(0).label();
        String busiest = byHour.stream().filter(h -> h.count() > 0)
                .max(Comparator.comparingLong(CountItem::count)).map(CountItem::label).orElse(null);
        return new Summary(total, previousCount, change, critical, high,
                pct(critical, total), dup, pct(dup, total), rangers,
                round(total / (double) days, 2), round(avgScore, 2), topType, busiest);
    }

    private List<String> buildInsights(Summary s, List<Hotspot> hotspots, List<CountItem> byType) {
        List<String> out = new ArrayList<>();
        if (s.totalIncidents() == 0) {
            out.add("No incidents were recorded in this period.");
            return out;
        }
        if (s.changePercent() != null) {
            out.add(String.format("Incident volume %s %.1f%% compared with the previous period (%d vs %d).",
                    s.changePercent() >= 0 ? "rose" : "fell", Math.abs(s.changePercent()),
                    s.totalIncidents(), s.previousPeriodIncidents()));
        }
        if (s.mostCommonType() != null && !byType.isEmpty()) {
            out.add(String.format("%s is the most frequent incident type (%d reports, %.0f%% of all).",
                    pretty(s.mostCommonType()), byType.get(0).count(), pct(byType.get(0).count(), s.totalIncidents())));
        }
        if (s.criticalIncidents() > 0) {
            out.add(String.format("%d critical incidents (%.1f%%) need priority follow-up.",
                    s.criticalIncidents(), s.criticalSharePercent()));
        }
        if (s.busiestHour() != null) {
            out.add("Reports peak around " + s.busiestHour() + " - consider scheduling patrols around that window.");
        }
        if (!hotspots.isEmpty() && hotspots.get(0).count() > 1) {
            Hotspot h = hotspots.get(0);
            out.add(String.format("Top hotspot near (%.3f, %.3f) with %d incidents, mostly %s.",
                    h.latitude(), h.longitude(), h.count(), pretty(h.dominantType())));
        }
        if (s.duplicateRatePercent() >= 10) {
            out.add(String.format("%.0f%% of reports were flagged as potential duplicates - review field reporting practice.",
                    s.duplicateRatePercent()));
        }
        return out;
    }

    private static String pretty(String enumName) {
        return enumName == null ? "" : enumName.replace('_', ' ').toLowerCase(Locale.ENGLISH);
    }

    private static double pct(long part, long whole) {
        return whole == 0 ? 0 : round(part * 100.0 / whole, 1);
    }

    private static double round(double v, int places) {
        double f = Math.pow(10, places);
        return Math.round(v * f) / f;
    }

    /** RFC-4180 quoting plus protection against spreadsheet formula injection. */
    private static String csv(String value) {
        if (value == null) return "";
        String v = value.replace("\r", " ").replace("\n", " ");
        if (!v.isEmpty() && "=+-@".indexOf(v.charAt(0)) >= 0) {
            v = "'" + v;
        }
        return "\"" + v.replace("\"", "\"\"") + "\"";
    }
}
