package com.wildlife.uc02.geometry;
import com.wildlife.uc02.entity.GeoPoint;
import org.springframework.stereotype.Component;
import java.util.List;
/** Bounding-box fallback strategy for invalid polygons (EF-06). */
@Component
public class BoundingBoxStrategy implements PointInPolygonStrategy {
    @Override
    public boolean contains(GeoPoint point, List<GeoPoint> polygon) {
        if (polygon == null || polygon.isEmpty()) return false;
        double minLat = Double.MAX_VALUE, maxLat = -Double.MAX_VALUE;
        double minLng = Double.MAX_VALUE, maxLng = -Double.MAX_VALUE;
        for (GeoPoint p : polygon) {
            minLat = Math.min(minLat, p.getLat()); maxLat = Math.max(maxLat, p.getLat());
            minLng = Math.min(minLng, p.getLng()); maxLng = Math.max(maxLng, p.getLng());
        }
        return point.getLat() >= minLat && point.getLat() <= maxLat && point.getLng() >= minLng && point.getLng() <= maxLng;
    }
}