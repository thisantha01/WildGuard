package com.wildlife.uc02.exception;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;
@ResponseStatus(HttpStatus.FORBIDDEN)
public class Uc02AccessDeniedException extends RuntimeException {
    public Uc02AccessDeniedException(String message) { super(message); }
}
