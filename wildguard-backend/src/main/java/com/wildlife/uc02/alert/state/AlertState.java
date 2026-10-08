package com.wildlife.uc02.alert.state;
import com.wildlife.uc02.entity.Alert;
/** State pattern interface for the Alert lifecycle. */
public interface AlertState {
    AlertState notified(Alert alert);
    AlertState acknowledged(Alert alert);
    AlertState inProgress(Alert alert);
    AlertState pendingResolution(Alert alert);
    AlertState resolved(Alert alert);
    AlertState escalated(Alert alert);
    AlertState deliveryFailed(Alert alert);
}