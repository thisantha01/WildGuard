package com.wildlife.uc02.entity;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** A latitude/longitude coordinate pair stored as an embedded document. */
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class GeoPoint {
    private double lat;
    private double lng;
}
