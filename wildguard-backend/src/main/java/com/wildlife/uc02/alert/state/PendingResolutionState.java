package com.wildlife.uc02.alert.state;
import com.wildlife.uc02.entity.Alert;
import com.wildlife.uc02.entity.AlertStatus;
public class PendingResolutionState extends AbstractAlertState {
    public static final PendingResolutionState INSTANCE = new PendingResolutionState();
    @Override protected AlertStatus currentStatus() { return AlertStatus.PENDING_RESOLUTION; }
    @Override public AlertState resolved(Alert a)   { return ResolvedState.INSTANCE; }
    @Override public AlertState inProgress(Alert a) { return InProgressState.INSTANCE; }
}