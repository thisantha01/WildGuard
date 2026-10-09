package com.wildlife.uc02.entity;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.DBRef;
import org.springframework.data.mongodb.core.mapping.Document;

import java.util.List;

/**
 * A geofence zone defined by a polygon of {@link GeoPoint} vertices.
 * valid=false means the polygon was geometrically invalid (EF-06 handling).
 */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@Document(collection = "uc02_geofence_zones")
public class GeofenceZone {
    @Id  private String id;
    @DBRef private Park park;
    private String parkId;
    private String name;
    private ZoneType type;
    private List<GeoPoint> polygon;
    @Builder.Default private boolean valid  = true;
    @Builder.Default private boolean active = true;
}
