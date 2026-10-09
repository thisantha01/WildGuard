package com.wildlife.uc02.entity;

/** All possible states in the alert lifecycle state machine. */
public enum AlertStatus {
    NEW,
    NOTIFIED,
    ACKNOWLEDGED,
    IN_PROGRESS,
    PENDING_RESOLUTION,
    RESOLVED,
    ESCALATED,
    DELIVERY_FAILED
}
