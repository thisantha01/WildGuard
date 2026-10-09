package com.wildlife.uc02.alert.state;
import com.wildlife.uc02.entity.Alert;
import com.wildlife.uc02.entity.AlertStatus;
public class EscalatedState extends AbstractAlertState {
    public static final EscalatedState INSTANCE = new EscalatedState();
    @Override protected AlertStatus currentStatus() { return AlertStatus.ESCALATED; }
    @Override public AlertState notified(Alert a) { return NotifiedState.INSTANCE; }
}