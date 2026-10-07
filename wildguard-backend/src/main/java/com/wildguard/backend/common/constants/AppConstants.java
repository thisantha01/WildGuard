package com.wildguard.backend.common.constants;

/**
 * Application-wide constants to eliminate magic strings and numbers.
 */
public final class AppConstants {

    private AppConstants() {
        // Prevent instantiation
    }

    // Role Constants (Spring Security Authority format)
    public static final String ROLE_PREFIX = "ROLE_";
    public static final String ROLE_RANGER = "ROLE_RANGER";
    public static final String ROLE_MANAGER = "ROLE_MANAGER";
    public static final String ROLE_LIAISON = "ROLE_LIAISON";

    // JWT Constants
    public static final String TOKEN_TYPE_BEARER = "Bearer";
    public static final String AUTH_HEADER = "Authorization";
    public static final int BEARER_PREFIX_LENGTH = 7;

    // Incident Sync & Validation Constants
    public static final int DUPLICATE_TIME_WINDOW_HOURS = 24;
    public static final double DUPLICATE_GEO_THRESHOLD_DELTA = 0.0001; // Approx ~11 meters
    public static final String SYNC_STATUS_SUCCESS = "SYNCED";
    public static final String SYNC_STATUS_DUPLICATE = "SYNCED_DUPLICATE_FLAGGED";

    // Coordinate Boundaries
    public static final double MIN_LATITUDE = -90.0;
    public static final double MAX_LATITUDE = 90.0;
    public static final double MIN_LONGITUDE = -180.0;
    public static final double MAX_LONGITUDE = 180.0;
}
