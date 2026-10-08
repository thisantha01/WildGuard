package com.wildlife.uc02.alert.state;
import com.wildlife.uc02.entity.Alert;
import com.wildlife.uc02.entity.AlertStatus;
public class NotifiedState extends AbstractAlertState {
    public static final NotifiedState INSTANCE = new NotifiedState();
    @Override protected AlertStatus currentStatus() { return AlertStatus.NOTIFIED; }
    @Override public AlertState notified(Alert a)       { return INSTANCE; }
    @Override public AlertState acknowledged(Alert a)   { return AcknowledgedState.INSTANCE; }
    @Override public AlertState escalated(Alert a)      { return EscalatedState.INSTANCE; }
    @Override public AlertState deliveryFailed(Alert a) { return DeliveryFailedState.INSTANCE; }
}