package com.wildlife.uc02.geometry;
import com.wildlife.uc02.entity.GeoPoint;
import org.springframework.stereotype.Component;
import java.util.List;
/** Ray-casting algorithm: primary point-in-polygon strategy. */
@Component
public class RayCastingStrategy implements PointInPolygonStrategy {
    @Override
    public boolean contains(GeoPoint point, List<GeoPoint> polygon) {
        if (polygon == null || polygon.size() < 3) return false;
        int crossings = 0;
        int n = polygon.size();
        for (int i = 0, j = n - 1; i < n; j = i++) {
            GeoPoint a = polygon.get(i); GeoPoint b = polygon.get(j);
            if (rayIntersectsEdge(point.getLat(), point.getLng(), a, b)) crossings++;
        }
        return (crossings % 2) == 1;
    }
    private boolean rayIntersectsEdge(double lat, double lng, GeoPoint a, GeoPoint b) {
        if ((a.getLng() > lng) == (b.getLng() > lng)) return false;
        double latAtCross = (a.getLat() - b.getLat()) * (lng - b.getLng()) / (a.getLng() - b.getLng()) + b.getLat();
        return lat < latAtCross;
    }
}