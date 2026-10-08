package com.wildlife.uc02.alert.event;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
@Slf4j
@Component
public class MockSmsGateway implements SmsGateway {
    @Override
    public void send(String phoneNumber, String message) {
        log.info("[MOCK SMS] To:{} Msg:{}", phoneNumber, message);
    }
}