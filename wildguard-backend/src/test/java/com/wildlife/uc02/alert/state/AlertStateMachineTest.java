package com.wildlife.uc02.alert.state;

import com.wildlife.uc02.entity.Alert;
import com.wildlife.uc02.entity.AlertStatus;
import com.wildlife.uc02.exception.InvalidAlertTransitionException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DisplayName("Alert State Machine Tests (State Pattern)")
class AlertStateMachineTest {

    @Test
    @DisplayName("should progress through standard happy path: NEW -> NOTIFIED -> ACKNOWLEDGED -> IN_PROGRESS -> PENDING_RESOLUTION -> RESOLVED")
    void should_followStandardLifecycle() {
        Alert alert = Alert.builder().status(AlertStatus.NEW).build();

        AlertState state = AlertStateFactory.of(alert.getStatus());
        state = state.notified(alert);
        assertThat(state).isInstanceOf(NotifiedState.class);

        state = state.acknowledged(alert);
        assertThat(state).isInstanceOf(AcknowledgedState.class);

        state = state.inProgress(alert);
        assertThat(state).isInstanceOf(InProgressState.class);

        state = state.pendingResolution(alert);
        assertThat(state).isInstanceOf(PendingResolutionState.class);

        state = state.resolved(alert);
        assertThat(state).isInstanceOf(ResolvedState.class);
    }

    @Test
    @DisplayName("should allow NOTIFIED -> ESCALATED and ACKNOWLEDGED -> ESCALATED")
    void should_allowEscalation() {
        Alert alert = Alert.builder().build();

        AlertState notified = NotifiedState.INSTANCE;
        assertThat(notified.escalated(alert)).isInstanceOf(EscalatedState.class);

        AlertState ack = AcknowledgedState.INSTANCE;
        assertThat(ack.escalated(alert)).isInstanceOf(EscalatedState.class);
    }

    @Test
    @DisplayName("should allow ESCALATED -> NOTIFIED when manager assigns ranger")
    void should_allowReassignmentFromEscalated() {
        Alert alert = Alert.builder().build();
        AlertState escalated = EscalatedState.INSTANCE;
        assertThat(escalated.notified(alert)).isInstanceOf(NotifiedState.class);
    }

    @Test
    @DisplayName("should allow PENDING_RESOLUTION -> IN_PROGRESS when animal re-breaches (AF-08)")
    void should_allowReBreachFromPendingResolution() {
        Alert alert = Alert.builder().build();
        AlertState pending = PendingResolutionState.INSTANCE;
        assertThat(pending.inProgress(alert)).isInstanceOf(InProgressState.class);
    }

    @Test
    @DisplayName("should allow NOTIFIED -> NOTIFIED on reassignment after decline/timeout")
    void should_allowReassignmentInNotifiedState() {
        Alert alert = Alert.builder().build();
        AlertState notified = NotifiedState.INSTANCE;
        assertThat(notified.notified(alert)).isInstanceOf(NotifiedState.class);
    }

    @Test
    @DisplayName("should allow NOTIFIED -> DELIVERY_FAILED when all retries exhausted")
    void should_allowDeliveryFailedFromNotified() {
        Alert alert = Alert.builder().build();
        AlertState notified = NotifiedState.INSTANCE;
        assertThat(notified.deliveryFailed(alert)).isInstanceOf(DeliveryFailedState.class);
    }

    @Test
    @DisplayName("should throw InvalidAlertTransitionException on invalid direct transition (NEW -> RESOLVED)")
    void should_throwOnInvalidTransition() {
        Alert alert = Alert.builder().build();
        AlertState newState = NewState.INSTANCE;

        assertThatThrownBy(() -> newState.resolved(alert))
                .isInstanceOf(InvalidAlertTransitionException.class);
    }

    @Test
    @DisplayName("should reject all transitions from terminal states RESOLVED and DELIVERY_FAILED")
    void should_rejectTransitionsFromTerminalStates() {
        Alert alert = Alert.builder().build();
        AlertState resolved = ResolvedState.INSTANCE;
        AlertState deliveryFailed = DeliveryFailedState.INSTANCE;

        assertThatThrownBy(() -> resolved.inProgress(alert)).isInstanceOf(InvalidAlertTransitionException.class);
        assertThatThrownBy(() -> resolved.notified(alert)).isInstanceOf(InvalidAlertTransitionException.class);
        assertThatThrownBy(() -> deliveryFailed.acknowledged(alert)).isInstanceOf(InvalidAlertTransitionException.class);
    }

    @ParameterizedTest
    @EnumSource(AlertStatus.class)
    @DisplayName("should map all AlertStatus enum values in AlertStateFactory")
    void should_mapAllStatuses(AlertStatus status) {
        AlertState state = AlertStateFactory.of(status);
        assertThat(state).isNotNull();
    }
}
