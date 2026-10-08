package com.wildlife.uc02.service.api;
import com.wildlife.uc02.entity.Alert;
/** Selects the best available ranger and CLO for an alert dispatch. */
public interface DispatchCoordinator {
    void dispatch(Alert alert);
}