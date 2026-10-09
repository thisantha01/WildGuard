package com.wildlife.uc02.alert.state;
import com.wildlife.uc02.entity.Alert;
import com.wildlife.uc02.entity.AlertStatus;
public class InProgressState extends AbstractAlertState {
    public static final InProgressState INSTANCE = new InProgressState();
    @Override protected AlertStatus currentStatus() { return AlertStatus.IN_PROGRESS; }
    @Override public AlertState pendingResolution(Alert a) { return PendingResolutionState.INSTANCE; }
}