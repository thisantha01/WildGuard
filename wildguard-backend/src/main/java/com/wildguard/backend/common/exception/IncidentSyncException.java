package com.wildguard.backend.common.exception;

public class IncidentSyncException extends RuntimeException {
    public IncidentSyncException(String message) {
        super(message);
    }

    public IncidentSyncException(String message, Throwable cause) {
        super(message, cause);
    }
}
