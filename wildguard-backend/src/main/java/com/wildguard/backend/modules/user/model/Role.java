package com.wildguard.backend.modules.user.model;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

/**
 * Roles available in the WildGuard system.
 */
public enum Role {
    ROLE_RANGER,
    ROLE_MANAGER,
    ROLE_LIAISON;

    /**
     * Parses string role (e.g. "RANGER", "ROLE_RANGER") to Role enum safely.
     */
    @JsonCreator
    public static Role fromString(String roleStr) {
        if (roleStr == null || roleStr.trim().isEmpty()) {
            return ROLE_RANGER;
        }
        String formatted = roleStr.trim().toUpperCase();
        if (!formatted.startsWith("ROLE_")) {
            formatted = "ROLE_" + formatted;
        }
        for (Role role : Role.values()) {
            if (role.name().equalsIgnoreCase(formatted)) {
                return role;
            }
        }
        throw new IllegalArgumentException("Unknown role: " + roleStr);
    }

    @JsonValue
    public String toValue() {
        return name();
    }
}
