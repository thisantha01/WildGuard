package com.wildlife.uc02.alert.state;
import com.wildlife.uc02.entity.AlertStatus;
public final class AlertStateFactory {
    private AlertStateFactory() {}
    public static AlertState of(AlertStatus status) {
        return switch (status) {
            case NEW               -> NewState.INSTANCE;
            case NOTIFIED          -> NotifiedState.INSTANCE;
            case ACKNOWLEDGED      -> AcknowledgedState.INSTANCE;
            case IN_PROGRESS       -> InProgressState.INSTANCE;
            case PENDING_RESOLUTION-> PendingResolutionState.INSTANCE;
            case RESOLVED          -> ResolvedState.INSTANCE;
            case ESCALATED         -> EscalatedState.INSTANCE;
            case DELIVERY_FAILED   -> DeliveryFailedState.INSTANCE;
        };
    }
}