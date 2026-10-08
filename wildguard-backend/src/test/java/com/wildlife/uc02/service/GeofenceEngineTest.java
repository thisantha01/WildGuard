package com.wildlife.uc02.service;

import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.geometry.*;
import com.wildlife.uc02.repository.GeofenceZoneRepository;
import com.wildlife.uc02.repository.ParkRepository;
import com.wildlife.uc02.repository.SystemLogRepository;
import com.wildlife.uc02.service.impl.GeofenceEngineImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("GeofenceEngine Unit Tests")
class GeofenceEngineTest {

    @Mock private GeofenceZoneRepository geofenceZoneRepository;
    @Mock private ParkRepository parkRepository;
    @Mock private SystemLogRepository systemLogRepository;

    private GeofenceEngineImpl engine;

    private final List<GeoPoint> validPolygon = List.of(
            new GeoPoint(6.3680, 81.4980),
            new GeoPoint(6.3720, 81.4980),
            new GeoPoint(6.3720, 81.5020),
            new GeoPoint(6.3680, 81.5020)
    );

    @BeforeEach
    void setUp() {
        engine = new GeofenceEngineImpl(
                geofenceZoneRepository, parkRepository,
                new RayCastingStrategy(), new BoundingBoxStrategy(),
                new PolygonValidator(), systemLogRepository);

        Park park = Park.builder().id("park-1").name("Yala").build();
        when(parkRepository.findAll()).thenReturn(List.of(park));
    }

    @Test
    @DisplayName("should detect breach when animal coordinate is inside active zone")
    void should_detectBreach_when_insideActiveZone() {
        GeofenceZone zone = GeofenceZone.builder().id("z1").name("Farmland").type(ZoneType.FARMLAND).active(true).polygon(validPolygon).build();
        when(geofenceZoneRepository.findByParkIdAndActiveTrue("park-1")).thenReturn(List.of(zone));

        Collar collar = Collar.builder().code("COL-001").build();
        TelemetryRecord telemetry = TelemetryRecord.builder().collar(collar).lat(6.3700).lng(81.5000).build();

        BreachResult result = engine.evaluate(Animal.builder().name("Rajah").build(), telemetry);

        assertThat(result.isInside()).isTrue();
        assertThat(result.getZone()).isEqualTo(zone);
        assertThat(result.isApproximateLocation()).isFalse();
    }

    @Test
    @DisplayName("should detect non-breach when animal is outside all active zones")
    void should_detectNonBreach_when_outsideAllZones() {
        GeofenceZone zone = GeofenceZone.builder().id("z1").name("Farmland").type(ZoneType.FARMLAND).active(true).polygon(validPolygon).build();
        when(geofenceZoneRepository.findByParkIdAndActiveTrue("park-1")).thenReturn(List.of(zone));

        Collar collar = Collar.builder().code("COL-001").build();
        TelemetryRecord telemetry = TelemetryRecord.builder().collar(collar).lat(6.3000).lng(81.4000).build();

        BreachResult result = engine.evaluate(Animal.builder().name("Rajah").build(), telemetry);

        assertThat(result.isInside()).isFalse();
    }

    @Test
    @DisplayName("should use in-memory cached zones when repository returns empty (EF-02)")
    void should_useCachedZones_when_dbReturnsEmpty() {
        GeofenceZone zone = GeofenceZone.builder().id("z1").name("Farmland").type(ZoneType.FARMLAND).active(true).polygon(validPolygon).build();
        // First call populates cache
        when(geofenceZoneRepository.findByParkIdAndActiveTrue("park-1")).thenReturn(List.of(zone));

        Collar collar = Collar.builder().code("COL-001").build();
        TelemetryRecord telemetry = TelemetryRecord.builder().collar(collar).lat(6.3700).lng(81.5000).build();
        engine.evaluate(Animal.builder().name("Rajah").build(), telemetry);

        // Second call: DB returns empty
        when(geofenceZoneRepository.findByParkIdAndActiveTrue("park-1")).thenReturn(List.of());

        BreachResult cachedResult = engine.evaluate(Animal.builder().name("Rajah").build(), telemetry);

        assertThat(cachedResult.isInside()).isTrue();
        verify(systemLogRepository).save(argThat(log -> log.getMessage().contains("Using cache")));
    }

    @Test
    @DisplayName("should fallback to bounding box and flag approximate location when polygon is invalid (EF-06)")
    void should_fallbackToBoundingBox_when_polygonInvalid() {
        List<GeoPoint> invalidPolygon = List.of(new GeoPoint(6.368, 81.498), new GeoPoint(6.372, 81.502));
        GeofenceZone invalidZone = GeofenceZone.builder().id("z-inv").name("Bad Polygon").type(ZoneType.FARMLAND).active(true).polygon(invalidPolygon).build();

        when(geofenceZoneRepository.findByParkIdAndActiveTrue("park-1")).thenReturn(List.of(invalidZone));

        Collar collar = Collar.builder().code("COL-001").build();
        TelemetryRecord telemetry = TelemetryRecord.builder().collar(collar).lat(6.3700).lng(81.5000).build();

        BreachResult result = engine.evaluate(Animal.builder().name("Rajah").build(), telemetry);

        assertThat(result.isInside()).isTrue();
        assertThat(result.isApproximateLocation()).isTrue();
        assertThat(invalidZone.isValid()).isFalse();
        verify(systemLogRepository).save(argThat(log -> log.getMessage().contains("EF-06: Invalid polygon")));
    }
}
