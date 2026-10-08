package com.wildlife.uc02.alert.state;
import com.wildlife.uc02.entity.Alert;
import com.wildlife.uc02.entity.AlertStatus;
import com.wildlife.uc02.exception.InvalidAlertTransitionException;
public abstract class AbstractAlertState implements AlertState {
    protected abstract AlertStatus currentStatus();
    protected InvalidAlertTransitionException illegal(AlertStatus t) { return new InvalidAlertTransitionException(currentStatus(), t); }
    @Override public AlertState notified(Alert a)          { throw illegal(AlertStatus.NOTIFIED); }
    @Override public AlertState acknowledged(Alert a)      { throw illegal(AlertStatus.ACKNOWLEDGED); }
    @Override public AlertState inProgress(Alert a)        { throw illegal(AlertStatus.IN_PROGRESS); }
    @Override public AlertState pendingResolution(Alert a) { throw illegal(AlertStatus.PENDING_RESOLUTION); }
    @Override public AlertState resolved(Alert a)          { throw illegal(AlertStatus.RESOLVED); }
    @Override public AlertState escalated(Alert a)         { throw illegal(AlertStatus.ESCALATED); }
    @Override public AlertState deliveryFailed(Alert a)    { throw illegal(AlertStatus.DELIVERY_FAILED); }
}