package com.wildlife.uc02.geometry;
import com.wildlife.uc02.entity.GeoPoint;
import java.util.List;
/** Strategy interface for point-in-polygon containment testing. */
public interface PointInPolygonStrategy {
    boolean contains(GeoPoint point, List<GeoPoint> polygon);
}