package com.wildlife.uc02.alert.event;
public interface SmsGateway {
    void send(String phoneNumber, String message);
}