package com.wildlife.uc02.alert.event;
public interface AlertEventListener {
    void onAlertEvent(AlertEvent event);
    boolean supports(AlertEvent.Type type);
}