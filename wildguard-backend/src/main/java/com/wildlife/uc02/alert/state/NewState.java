package com.wildlife.uc02.alert.state;
import com.wildlife.uc02.entity.Alert;
import com.wildlife.uc02.entity.AlertStatus;
public class NewState extends AbstractAlertState {
    public static final NewState INSTANCE = new NewState();
    @Override protected AlertStatus currentStatus() { return AlertStatus.NEW; }
    @Override public AlertState notified(Alert a) { return NotifiedState.INSTANCE; }
}