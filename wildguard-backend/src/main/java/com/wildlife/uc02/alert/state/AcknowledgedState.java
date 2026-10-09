package com.wildlife.uc02.alert.state;
import com.wildlife.uc02.entity.Alert;
import com.wildlife.uc02.entity.AlertStatus;
public class AcknowledgedState extends AbstractAlertState {
    public static final AcknowledgedState INSTANCE = new AcknowledgedState();
    @Override protected AlertStatus currentStatus() { return AlertStatus.ACKNOWLEDGED; }
    @Override public AlertState inProgress(Alert a)     { return InProgressState.INSTANCE; }
    @Override public AlertState escalated(Alert a)      { return EscalatedState.INSTANCE; }
    @Override public AlertState deliveryFailed(Alert a) { return DeliveryFailedState.INSTANCE; }
}