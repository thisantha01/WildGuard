package com.wildlife.uc02.exception;
import com.wildguard.backend.common.exception.ErrorResponse;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import java.time.Instant;
@Slf4j
@Order(1)
@RestControllerAdvice(basePackages = "com.wildlife.uc02")
public class Uc02ExceptionHandler {
    @ExceptionHandler(InvalidAlertTransitionException.class)
    public ResponseEntity<ErrorResponse> handleInvalidTransition(InvalidAlertTransitionException ex, HttpServletRequest req) {
        log.warn("Invalid alert transition at {}: {}", req.getRequestURI(), ex.getMessage());
        return ResponseEntity.status(HttpStatus.CONFLICT).body(buildError(HttpStatus.CONFLICT, ex.getMessage(), req));
    }
    @ExceptionHandler(TelemetryValidationException.class)
    public ResponseEntity<ErrorResponse> handleTelemetryValidation(TelemetryValidationException ex, HttpServletRequest req) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(buildError(HttpStatus.BAD_REQUEST, ex.getMessage(), req));
    }
    @ExceptionHandler({AlertNotFoundException.class, CollarNotFoundException.class, RangerNotFoundException.class, AnimalNotFoundException.class})
    public ResponseEntity<ErrorResponse> handleNotFound(RuntimeException ex, HttpServletRequest req) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(buildError(HttpStatus.NOT_FOUND, ex.getMessage(), req));
    }
    @ExceptionHandler(Uc02AccessDeniedException.class)
    public ResponseEntity<ErrorResponse> handleAccessDenied(Uc02AccessDeniedException ex, HttpServletRequest req) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(buildError(HttpStatus.FORBIDDEN, ex.getMessage(), req));
    }
    private ErrorResponse buildError(HttpStatus status, String message, HttpServletRequest req) {
        return ErrorResponse.builder().timestamp(Instant.now()).status(status.value())
                .error(status.getReasonPhrase()).message(message).path(req.getRequestURI()).build();
    }
}
