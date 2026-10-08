package com.wildguard.backend.modules.teammates.uc04_analytics;

import com.wildguard.backend.common.exception.ValidationException;
import com.wildguard.backend.modules.incident.model.GeoLocation;
import com.wildguard.backend.modules.incident.model.Incident;
import com.wildguard.backend.modules.incident.model.IncidentSeverity;
import com.wildguard.backend.modules.incident.model.IncidentType;
import com.wildguard.backend.modules.teammates.uc04_analytics.dto.AnalyticsDashboardResponse;
import com.wildguard.backend.modules.teammates.uc04_analytics.repository.IncidentAnalyticsRepository;
import com.wildguard.backend.modules.teammates.uc04_analytics.service.impl.ConservationAnalyticsServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@DisplayName("ConservationAnalyticsService Unit Tests")
class ConservationAnalyticsServiceTest {

    @Mock
    private IncidentAnalyticsRepository repository;

    private ConservationAnalyticsServiceImpl service;

    private static final LocalDate FROM = LocalDate.of(2026, 10, 1);
    private static final LocalDate TO = LocalDate.of(2026, 10, 7);

    @BeforeEach
    void setUp() {
        service = new ConservationAnalyticsServiceImpl(repository);
    }

    private Incident incident(IncidentType type, IncidentSeverity sev, String ranger,
                              String ts, double lat, double lng, boolean dup) {
        return Incident.builder()
                .id("id-" + ts + ranger)
                .type(type).severity(sev).rangerUsername(ranger)
                .timestamp(Instant.parse(ts))
                .location(GeoLocation.builder().latitude(lat).longitude(lng).build())
                .duplicateFlag(dup)
                .description("test")
                .build();
    }

    @Test
    @DisplayName("Builds summary, breakdowns, trend and hotspots from incidents")
    void dashboardAggregates() {
        List<Incident> data = List.of(
                incident(IncidentType.SNARE, IncidentSeverity.CRITICAL, "alice", "2026-10-02T08:10:00Z", 7.1001, 80.2001, false),
                incident(IncidentType.SNARE, IncidentSeverity.HIGH, "alice", "2026-10-02T08:40:00Z", 7.1002, 80.2002, true),
                incident(IncidentType.CARCASS, IncidentSeverity.LOW, "bob", "2026-10-05T14:00:00Z", 7.5, 80.9, false));
        when(repository.find(any(), any(), isNull(), isNull(), isNull())).thenReturn(data);
        when(repository.count(any(), any(), isNull(), isNull(), isNull())).thenReturn(2L);

        AnalyticsDashboardResponse r = service.getDashboard(FROM, TO, "UTC", null, null, null);

        assertEquals(3, r.summary().totalIncidents());
        assertEquals(50.0, r.summary().changePercent());
        assertEquals(1, r.summary().criticalIncidents());
        assertEquals(1, r.summary().duplicateFlagged());
        assertEquals(2, r.summary().activeRangers());
        assertEquals("SNARE", r.summary().mostCommonType());
        assertEquals("08:00", r.summary().busiestHour());
        assertEquals(7, r.dailyTrend().size());
        assertEquals(4, r.bySeverity().size());
        assertEquals(24, r.byHourOfDay().size());
        assertEquals(2, r.hotspots().get(0).count());
        assertEquals("alice", r.rangerActivity().get(0).rangerUsername());
        assertFalse(r.insights().isEmpty());
    }

    @Test
    @DisplayName("Empty data returns zeros and a friendly insight")
    void emptyData() {
        when(repository.find(any(), any(), any(), any(), any())).thenReturn(List.of());
        when(repository.count(any(), any(), any(), any(), any())).thenReturn(0L);

        AnalyticsDashboardResponse r = service.getDashboard(FROM, TO, "UTC", null, null, null);

        assertEquals(0, r.summary().totalIncidents());
        assertNull(r.summary().changePercent());
        assertEquals(1, r.insights().size());
    }

    @Test
    @DisplayName("Rejects inverted date range and unknown timezone")
    void validation() {
        assertThrows(ValidationException.class, () -> service.getDashboard(TO, FROM, "UTC", null, null, null));
        assertThrows(ValidationException.class, () -> service.getDashboard(FROM, TO, "Mars/Base", null, null, null));
    }

    @Test
    @DisplayName("CSV export escapes quotes and neutralises formula injection")
    void csvExport() {
        Incident i = incident(IncidentType.TRAP, IncidentSeverity.MEDIUM, "alice", "2026-10-02T08:10:00Z", 7.1, 80.2, false);
        i.setDescription("=cmd|' /C calc'!A0 \"quoted\"");
        when(repository.find(any(), any(), any(), any(), any())).thenReturn(List.of(i));

        String csv = service.exportCsv(FROM, TO, "UTC", null, null, null);

        assertTrue(csv.startsWith("id,timestamp,type"));
        assertTrue(csv.contains("\"'=cmd"));
        assertTrue(csv.contains("\"\"quoted\"\""));
    }
}
