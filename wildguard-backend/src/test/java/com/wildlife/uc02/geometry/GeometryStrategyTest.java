package com.wildlife.uc02.geometry;

import com.wildlife.uc02.entity.GeoPoint;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@DisplayName("Geometry and Ray-Casting Strategy Tests")
class GeometryStrategyTest {

    private final RayCastingStrategy rayCasting = new RayCastingStrategy();
    private final BoundingBoxStrategy boundingBox = new BoundingBoxStrategy();
    private final PolygonValidator validator = new PolygonValidator();

    private final List<GeoPoint> squarePolygon = List.of(
            new GeoPoint(6.3680, 81.4980),
            new GeoPoint(6.3720, 81.4980),
            new GeoPoint(6.3720, 81.5020),
            new GeoPoint(6.3680, 81.5020)
    );

    @Test
    @DisplayName("should detect inside when point is strictly inside polygon")
    void should_detectInside_when_pointInsidePolygon() {
        boolean inside = rayCasting.contains(new GeoPoint(6.3700, 81.5000), squarePolygon);
        assertThat(inside).isTrue();
    }

    @Test
    @DisplayName("should detect outside when point is clearly outside polygon")
    void should_detectOutside_when_pointOutsidePolygon() {
        boolean inside = rayCasting.contains(new GeoPoint(6.3600, 81.4900), squarePolygon);
        assertThat(inside).isFalse();
    }

    @Test
    @DisplayName("should validate polygon vertex count")
    void should_validatePolygonVertexCount() {
        assertThat(validator.isValid(squarePolygon)).isTrue();

        List<GeoPoint> invalidPolygon = List.of(
                new GeoPoint(6.3680, 81.4980),
                new GeoPoint(6.3720, 81.5020)
        );
        assertThat(validator.isValid(invalidPolygon)).isFalse();
    }

    @Test
    @DisplayName("should evaluate bounding box contains when polygon is tested (EF-06)")
    void should_evaluateBoundingBox_forFallback() {
        List<GeoPoint> twoPoints = List.of(
                new GeoPoint(6.3680, 81.4980),
                new GeoPoint(6.3720, 81.5020)
        );
        boolean inside = boundingBox.contains(new GeoPoint(6.3700, 81.5000), twoPoints);
        assertThat(inside).isTrue();

        boolean outside = boundingBox.contains(new GeoPoint(6.4000, 81.6000), twoPoints);
        assertThat(outside).isFalse();
    }

    @Test
    @DisplayName("should accurately compute distance and eta via HaversineUtil")
    void should_calculateDistance_with_haversine() {
        double distKm = HaversineUtil.distanceKm(6.3700, 81.5000, 6.3400, 81.5200);
        assertThat(distKm).isBetween(3.5, 5.5);

        double distM = HaversineUtil.distanceMeters(6.3700, 81.5000, 6.3750, 81.5050);
        assertThat(distM).isBetween(500.0, 1000.0);

        int eta = HaversineUtil.etaMinutes(distKm, 40);
        assertThat(eta).isGreaterThan(0);
        assertThat(HaversineUtil.etaMinutes(10, 0)).isEqualTo(Integer.MAX_VALUE);
    }
}
