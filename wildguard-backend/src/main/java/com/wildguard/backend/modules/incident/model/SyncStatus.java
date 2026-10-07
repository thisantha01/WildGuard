package com.wildguard.backend.modules.incident.model;

/**
 * Synchronization status of offline records.
 */
public enum SyncStatus {
    PENDING,
    SYNCED,
    SYNCED_DUPLICATE_FLAGGED,
    FAILED
}
