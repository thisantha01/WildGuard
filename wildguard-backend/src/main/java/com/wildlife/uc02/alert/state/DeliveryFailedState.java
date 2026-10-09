package com.wildlife.uc02.alert.state;
import com.wildlife.uc02.entity.Alert;
import com.wildlife.uc02.entity.AlertStatus;
public class DeliveryFailedState extends AbstractAlertState {
    public static final DeliveryFailedState INSTANCE = new DeliveryFailedState();
    @Override protected AlertStatus currentStatus() { return AlertStatus.DELIVERY_FAILED; }
}