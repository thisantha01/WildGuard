package com.wildlife.uc02.alert.event;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import java.util.List;
@Slf4j
@Component
public class AlertEventPublisherImpl implements AlertEventPublisher {
    private final List<AlertEventListener> listeners;
    public AlertEventPublisherImpl(List<AlertEventListener> listeners) { this.listeners = listeners; }
    @Override
    public void publish(AlertEvent event) {
        log.debug("Publishing alert event {} for alert {}", event.getType(), event.getAlert().getId());
        listeners.stream().filter(l -> l.supports(event.getType())).forEach(l -> {
            try { l.onAlertEvent(event); }
            catch (Exception ex) { log.error("Alert event listener {} failed: {}", l.getClass().getSimpleName(), ex.getMessage()); }
        });
    }
}