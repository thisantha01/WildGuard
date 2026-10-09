package com.wildlife.uc02.geometry;
import com.wildlife.uc02.entity.GeofenceZone;
import lombok.*;
/** Immutable result from GeofenceEngine. The engine ONLY decides; never creates alerts. */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class BreachResult {
    private boolean inside;
    private GeofenceZone zone;
    private boolean approximateLocation;
}