package com.wildlife.uc02;

import com.wildlife.uc02.alert.event.AlertEvent;
import com.wildlife.uc02.alert.event.AlertEventPublisher;
import com.wildlife.uc02.dto.FieldReportRequest;
import com.wildlife.uc02.dto.TelemetryRequest;
import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.geometry.BoundingBoxStrategy;
import com.wildlife.uc02.geometry.PolygonValidator;
import com.wildlife.uc02.geometry.RayCastingStrategy;
import com.wildlife.uc02.repository.*;
import com.wildlife.uc02.service.api.AlertManager;
import com.wildlife.uc02.service.api.NotificationService;
import com.wildlife.uc02.service.api.ReEntryEvaluator;
import com.wildlife.uc02.service.impl.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("UC02 End-to-End Main Lifecycle Integration Test")
class Uc02EndToEndFlowTest {

    @Mock private CollarRepository collarRepository;
    @Mock private TelemetryRecordRepository telemetryRepository;
    @Mock private MaintenanceAlertRepository maintenanceAlertRepository;
    @Mock private SystemLogRepository systemLogRepository;
    @Mock private GeofenceZoneRepository geofenceZoneRepository;
    @Mock private ParkRepository parkRepository;
    @Mock private SettlementRepository settlementRepository;
    @Mock private AlertRepository alertRepository;
    @Mock private AlertStatusHistoryRepository historyRepository;
    @Mock private AlertTelemetryLinkRepository telemetryLinkRepository;
    @Mock private AlertAssignmentRepository assignmentRepository;
    @Mock private FieldReportRepository fieldReportRepository;
    @Mock private RangerStatusRepository rangerStatusRepository;
    @Mock private CloRepository cloRepository;
    @Mock private NotificationService notificationService;
    @Mock private AlertEventPublisher eventPublisher;

    private Clock clock;
    private TelemetryIngestionServiceImpl telemetryIngestionService;
    private AlertManagerImpl alertManager;
    private DispatchCoordinatorImpl dispatchCoordinator;
    private GeofenceEngineImpl geofenceEngine;
    private ThreatAssessorImpl threatAssessor;
    private ReEntryEvaluatorImpl reEntryEvaluator;

    private Animal rajah;
    private Collar collar;
    private GeofenceZone farmlandZone;
    private RangerStatus samanRanger;
    private Park park;
    private Alert activeAlert;

    @BeforeEach
    void setUp() {
        clock = Clock.fixed(Instant.parse("2026-10-08T10:00:00Z"), ZoneOffset.UTC);

        ParkConfig config = ParkConfig.builder()
                .groupingRadiusM(500)
                .rangerSearchRadiusKm(30)
                .rangerLocationStaleMin(30)
                .reEntryConsecutivePackets(2)
                .averageSpeedKmh(40)
                .build();
        park = Park.builder().id("park-yala").name("Yala National Park").config(config).build();
        when(parkRepository.findAll()).thenReturn(List.of(park));
        when(parkRepository.findById("park-yala")).thenReturn(Optional.of(park));

        threatAssessor = new ThreatAssessorImpl(settlementRepository, alertRepository, clock);
        geofenceEngine = new GeofenceEngineImpl(
                geofenceZoneRepository, parkRepository,
                new RayCastingStrategy(), new BoundingBoxStrategy(),
                new PolygonValidator(), systemLogRepository);

        alertManager = new AlertManagerImpl(
                alertRepository, historyRepository, telemetryLinkRepository,
                assignmentRepository, fieldReportRepository, parkRepository,
                rangerStatusRepository, threatAssessor, null,
                notificationService, eventPublisher, systemLogRepository, clock);

        dispatchCoordinator = new DispatchCoordinatorImpl(
                rangerStatusRepository, cloRepository, alertRepository,
                assignmentRepository, parkRepository, notificationService,
                eventPublisher, alertManager, clock);

        // Inject dispatchCoordinator into alertManager via reflection or setter
        try {
            var field = AlertManagerImpl.class.getDeclaredField("dispatchCoordinator");
            field.setAccessible(true);
            field.set(alertManager, dispatchCoordinator);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }

        reEntryEvaluator = new ReEntryEvaluatorImpl(alertRepository, parkRepository, alertManager);

        telemetryIngestionService = new TelemetryIngestionServiceImpl(
                collarRepository, telemetryRepository, maintenanceAlertRepository,
                systemLogRepository, geofenceEngine, alertManager, clock);

        // Seed domain objects
        rajah = Animal.builder().id("animal-1").name("Rajah").tagId("ELE-024").species("Sri Lankan Elephant").build();
        collar = Collar.builder().id("col-1").code("COL-024").animal(rajah).batteryPercent(85).build();

        farmlandZone = GeofenceZone.builder()
                .id("zone-farmland").name("Yala Sector 04 Farmland")
                .type(ZoneType.FARMLAND).active(true).valid(true)
                .polygon(List.of(
                        new GeoPoint(6.3680, 81.4980),
                        new GeoPoint(6.3720, 81.4980),
                        new GeoPoint(6.3720, 81.5020),
                        new GeoPoint(6.3680, 81.5020)
                ))
                .build();

        samanRanger = RangerStatus.builder()
                .userId("saman_p").name("Saman P").unitCode("R-07")
                .availability(RangerAvailability.AVAILABLE)
                .lastLat(6.3400).lastLng(81.5200)
                .lastLocationAt(Instant.now(clock))
                .build();
    }

    @Test
    @DisplayName("Complete UC02 End-to-End flow: Telemetry Breach -> NEW -> NOTIFIED -> ACKNOWLEDGED -> IN_PROGRESS -> PENDING_RESOLUTION -> RESOLVED")
    void should_completeFullUc02LifecycleSuccessfully() {
        // Step 1: Telemetry Breach packet arrives from Rajah inside farmland
        when(collarRepository.findByCode("COL-024")).thenReturn(Optional.of(collar));
        when(geofenceZoneRepository.findByParkIdAndActiveTrue("park-yala")).thenReturn(List.of(farmlandZone));
        when(telemetryRepository.findByCollarIdAndTimestamp(any(), any())).thenReturn(Optional.empty());
        when(telemetryRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        when(rangerStatusRepository.findByParkIdAndAvailability("park-yala", RangerAvailability.AVAILABLE))
                .thenReturn(List.of(samanRanger));
        when(assignmentRepository.findByAlertIdAndOutcomeIn(any(), any())).thenReturn(List.of());

        List<Alert> storedAlerts = new ArrayList<>();
        when(alertRepository.save(any(Alert.class))).thenAnswer(inv -> {
            Alert a = inv.getArgument(0);
            if (a.getId() == null) a.setId("alt-001");
            activeAlert = a;
            storedAlerts.add(a);
            return a;
        });
        when(alertRepository.findByAnimalIdAndStatusNotIn(eq("animal-1"), any())).thenReturn(List.of());
        when(alertRepository.findById("alt-001")).thenAnswer(inv -> Optional.ofNullable(activeAlert));

        TelemetryRequest breachPacket = TelemetryRequest.builder()
                .collarCode("COL-024")
                .latitude(6.3700)
                .longitude(81.5000)
                .batteryPercent(85)
                .timestamp(Instant.now(clock))
                .checksum("chk-1")
                .build();

        // INGESTION: Detects breach -> Threat Assessed -> Created NEW -> NOTIFIED -> Dispatched to Saman P
        telemetryIngestionService.ingest(breachPacket);

        assertThat(activeAlert).isNotNull();
        assertThat(activeAlert.getStatus()).isEqualTo(AlertStatus.NOTIFIED);
        assertThat(activeAlert.getAssignedRangerId()).isEqualTo("saman_p");
        verify(notificationService).notifyRanger(eq(activeAlert), eq("saman_p"));

        // Step 2: Ranger Saman acknowledges the alert
        alertManager.acknowledge("alt-001", "saman_p");
        assertThat(activeAlert.getStatus()).isEqualTo(AlertStatus.ACKNOWLEDGED);

        // Step 3: Ranger confirms dispatch (en route)
        alertManager.confirmDispatch("alt-001", "saman_p");
        assertThat(activeAlert.getStatus()).isEqualTo(AlertStatus.IN_PROGRESS);

        // Step 4: Animal moves safely outside zone. 1st non-breach telemetry packet
        TelemetryRecord safePacket1 = TelemetryRecord.builder().lat(6.3300).lng(81.4500).build();
        when(alertRepository.findByAnimalIdAndStatusNotIn(eq("animal-1"), any())).thenReturn(List.of(activeAlert));

        alertManager.handleNonBreach(rajah, safePacket1);
        // Alert remains IN_PROGRESS after 1st packet (threshold is 2)
        assertThat(activeAlert.getStatus()).isEqualTo(AlertStatus.IN_PROGRESS);

        // Step 5: 2nd consecutive packet outside zone -> threshold met -> PENDING_RESOLUTION (AF-05)
        TelemetryRecord safePacket2 = TelemetryRecord.builder().lat(6.3290).lng(81.4510).build();
        alertManager.handleNonBreach(rajah, safePacket2);
        assertThat(activeAlert.getStatus()).isEqualTo(AlertStatus.PENDING_RESOLUTION);

        // Step 6: Ranger verifies situation and submits FieldReport with situationSafe=true -> RESOLVED
        FieldReportRequest report = FieldReportRequest.builder()
                .cropDamage(CropDamage.MINOR)
                .injuries(InjurySeverity.NONE)
                .situationSafe(true)
                .notes("Elephant herd steered safely back across the park boundary")
                .build();

        alertManager.submitFieldReport("alt-001", "saman_p", report);

        // VERIFY FINAL RESOLVED STATUS
        assertThat(activeAlert.getStatus()).isEqualTo(AlertStatus.RESOLVED);
        assertThat(activeAlert.getResolvedAt()).isNotNull();
        verify(fieldReportRepository).save(any(FieldReport.class));
        verify(eventPublisher).publish(argThat(e -> e.getType() == AlertEvent.Type.RESOLVED));
    }
}
