package com.wildlife.uc02.alert.event;
import com.wildlife.uc02.entity.Alert;
public interface AlertEventPublisher {
    void publish(AlertEvent event);
}