package com.wildlife.uc02.geometry;
import com.wildlife.uc02.entity.GeoPoint;
import org.springframework.stereotype.Component;
import java.util.List;
/** Validates polygon geometry: minimum vertex count and self-intersection check. */
@Component
public class PolygonValidator {
    private static final int MIN_VERTICES = 3;
    public boolean isValid(List<GeoPoint> polygon) {
        if (polygon == null || polygon.size() < MIN_VERTICES) return false;
        return !hasSelfIntersection(polygon);
    }
    private boolean hasSelfIntersection(List<GeoPoint> polygon) {
        int n = polygon.size();
        for (int i = 0; i < n; i++) {
            int iNext = (i + 1) % n;
            for (int j = i + 2; j < n; j++) {
                int jNext = (j + 1) % n;
                if (jNext == i || (i == 0 && j == n - 1)) continue;
                if (segmentsIntersect(polygon.get(i), polygon.get(iNext), polygon.get(j), polygon.get(jNext))) return true;
            }
        }
        return false;
    }
    private boolean segmentsIntersect(GeoPoint p1, GeoPoint p2, GeoPoint p3, GeoPoint p4) {
        double d1 = dir(p3,p4,p1), d2 = dir(p3,p4,p2), d3 = dir(p1,p2,p3), d4 = dir(p1,p2,p4);
        if (((d1>0&&d2<0)||(d1<0&&d2>0))&&((d3>0&&d4<0)||(d3<0&&d4>0))) return true;
        if (d1==0&&onSeg(p3,p4,p1)) return true;
        if (d2==0&&onSeg(p3,p4,p2)) return true;
        if (d3==0&&onSeg(p1,p2,p3)) return true;
        if (d4==0&&onSeg(p1,p2,p4)) return true;
        return false;
    }
    private double dir(GeoPoint i, GeoPoint j, GeoPoint k) {
        return (k.getLat()-i.getLat())*(j.getLng()-i.getLng())-(j.getLat()-i.getLat())*(k.getLng()-i.getLng());
    }
    private boolean onSeg(GeoPoint i, GeoPoint j, GeoPoint k) {
        return Math.min(i.getLat(),j.getLat())<=k.getLat()&&k.getLat()<=Math.max(i.getLat(),j.getLat())
            &&Math.min(i.getLng(),j.getLng())<=k.getLng()&&k.getLng()<=Math.max(i.getLng(),j.getLng());
    }
}