package com.wildlife.uc02.exception;
import com.wildlife.uc02.entity.AlertStatus;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;
@ResponseStatus(HttpStatus.CONFLICT)
public class InvalidAlertTransitionException extends RuntimeException {
    public InvalidAlertTransitionException(AlertStatus from, AlertStatus to) {
        super(String.format("Invalid alert transition: %s -> %s", from, to));
    }
    public InvalidAlertTransitionException(String message) { super(message); }
}
