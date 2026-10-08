package com.wildlife.uc02.alert.state;
import com.wildlife.uc02.entity.Alert;
import com.wildlife.uc02.entity.AlertStatus;
public class ResolvedState extends AbstractAlertState {
    public static final ResolvedState INSTANCE = new ResolvedState();
    @Override protected AlertStatus currentStatus() { return AlertStatus.RESOLVED; }
}