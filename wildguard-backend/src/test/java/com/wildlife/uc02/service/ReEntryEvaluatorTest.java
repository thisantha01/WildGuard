package com.wildlife.uc02.service;

import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.repository.AlertRepository;
import com.wildlife.uc02.repository.ParkRepository;
import com.wildlife.uc02.service.api.AlertManager;
import com.wildlife.uc02.service.impl.ReEntryEvaluatorImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("ReEntryEvaluator Unit Tests")
class ReEntryEvaluatorTest {

    @Mock private AlertRepository alertRepository;
    @Mock private ParkRepository parkRepository;
    @Mock private AlertManager alertManager;

    private ReEntryEvaluatorImpl evaluator;
    private Animal animal;
    private Alert inProgressAlert;

    @BeforeEach
    void setUp() {
        evaluator = new ReEntryEvaluatorImpl(alertRepository, parkRepository, alertManager);
        animal = Animal.builder().id("animal-1").name("Rajah").build();
        inProgressAlert = Alert.builder().id("alt-1").displayCode("ALT-0001").status(AlertStatus.IN_PROGRESS).parkId("park-1").build();

        Park park = Park.builder().config(ParkConfig.builder().reEntryConsecutivePackets(2).build()).build();
        when(parkRepository.findById("park-1")).thenReturn(Optional.of(park));
    }

    @Test
    @DisplayName("should transition alert to PENDING_RESOLUTION when consecutive outside count reaches threshold (AF-05)")
    void should_transitionToPendingResolution_whenThresholdMet() {
        when(alertRepository.findByAnimalIdAndStatusNotIn(eq("animal-1"), any()))
                .thenReturn(List.of(inProgressAlert));

        TelemetryRecord t1 = TelemetryRecord.builder().lat(6.3300).lng(81.4500).build();
        TelemetryRecord t2 = TelemetryRecord.builder().lat(6.3290).lng(81.4510).build();

        // 1st outside packet: count becomes 1, no transition yet
        evaluator.evaluateNonBreach(animal, t1);
        assertThat(evaluator.getConsecutiveOutsideCount("animal-1")).isEqualTo(1);
        verify(alertManager, never()).transitionAlert(any(), any(), any(), any());

        // 2nd outside packet: count meets threshold 2 -> transitions!
        evaluator.evaluateNonBreach(animal, t2);
        assertThat(evaluator.getConsecutiveOutsideCount("animal-1")).isEqualTo(0);
        verify(alertManager).transitionAlert(eq(inProgressAlert), eq(AlertStatus.PENDING_RESOLUTION), eq("system"), anyString());
    }

    @Test
    @DisplayName("should reset consecutive count and revert PENDING_RESOLUTION to IN_PROGRESS on breach (AF-08 / flapping)")
    void should_resetCountAndRevertOnBreach() {
        Alert pendingAlert = Alert.builder().id("alt-2").displayCode("ALT-0002").status(AlertStatus.PENDING_RESOLUTION).parkId("park-1").build();
        when(alertRepository.findByAnimalIdAndStatusNotIn(eq("animal-1"), any()))
                .thenReturn(List.of(pendingAlert));

        evaluator.evaluateBreach(animal, TelemetryRecord.builder().build());

        assertThat(evaluator.getConsecutiveOutsideCount("animal-1")).isEqualTo(0);
        verify(alertManager).transitionAlert(eq(pendingAlert), eq(AlertStatus.IN_PROGRESS), eq("system"), contains("AF-08"));
    }
}
