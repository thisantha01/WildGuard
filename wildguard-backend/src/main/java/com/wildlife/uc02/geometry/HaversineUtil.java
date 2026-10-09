package com.wildlife.uc02.geometry;

/** Pure-function haversine distance utility. No state, no Spring dependency. */
public final class HaversineUtil {
    private static final double EARTH_RADIUS_KM = 6371.0;

    private HaversineUtil() {}

    public static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return EARTH_RADIUS_KM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    public static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
        return distanceKm(lat1, lng1, lat2, lng2) * 1000.0;
    }

    public static int etaMinutes(double distanceKm, int speedKmh) {
        if (speedKmh <= 0) return Integer.MAX_VALUE;
        return (int) Math.ceil((distanceKm / speedKmh) * 60.0);
    }
}