package com.wildlife.uc02.exception;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;
@ResponseStatus(HttpStatus.NOT_FOUND)
public class RangerNotFoundException extends RuntimeException {
    public RangerNotFoundException(String msg) { super(msg); }
}
