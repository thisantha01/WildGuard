package com.wildlife.uc02.scheduler;

import com.wildlife.uc02.entity.Collar;
import com.wildlife.uc02.entity.CollarStatus;
import com.wildlife.uc02.entity.MaintenanceAlert;
import com.wildlife.uc02.entity.MaintenanceAlertType;
import com.wildlife.uc02.entity.Park;
import com.wildlife.uc02.repository.CollarRepository;
import com.wildlife.uc02.repository.MaintenanceAlertRepository;
import com.wildlife.uc02.repository.ParkRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Instant;
import java.util.List;

/**
 * Component 8: CollarHealthMonitor (@Scheduled)
 * AF-01: battery <= lowBatteryPercent -> LOW_BATTERY MaintenanceAlert for TECHNICIAN (one open per collar).
 * AF-02: no packet for transmissionGapMin -> TRANSMISSION_GAP MaintenanceAlert + update status.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class CollarHealthMonitor {

    private final CollarRepository collarRepository;
    private final MaintenanceAlertRepository maintenanceAlertRepository;
    private final ParkRepository parkRepository;
    private final Clock clock;

    @Scheduled(fixedDelayString = "${uc02.scheduler.collar-health-ms:60000}")
    public void monitorCollarHealth() {
        Park park = parkRepository.findAll().stream().findFirst().orElse(null);
        int lowBatteryPercent = park != null ? park.getConfig().getLowBatteryPercent() : 20;
        int transmissionGapMin = park != null ? park.getConfig().getTransmissionGapMin() : 30;

        Instant now = Instant.now(clock);
        Instant cutoff = now.minusSeconds(transmissionGapMin * 60L);

        List<Collar> collars = collarRepository.findAll();

        for (Collar collar : collars) {
            checkBattery(collar, lowBatteryPercent, now);
            checkTransmissionGap(collar, cutoff, now);
        }
    }

    private void checkBattery(Collar collar, int lowBatteryThreshold, Instant now) {
        if (collar.getBatteryPercent() <= lowBatteryThreshold) {
            boolean openAlertExists = maintenanceAlertRepository
                    .findByCollarIdAndTypeAndResolvedFalse(collar.getId(), MaintenanceAlertType.LOW_BATTERY)
                    .isPresent();

            if (!openAlertExists) {
                log.warn("AF-01: Low battery ({}%) detected on collar {}. Creating MaintenanceAlert.",
                        collar.getBatteryPercent(), collar.getCode());
                maintenanceAlertRepository.save(MaintenanceAlert.builder()
                        .collar(collar)
                        .type(MaintenanceAlertType.LOW_BATTERY)
                        .createdAt(now)
                        .resolved(false)
                        .build());
                collar.setStatus(CollarStatus.LOW_BATTERY);
                collarRepository.save(collar);
            }
        }
    }

    private void checkTransmissionGap(Collar collar, Instant cutoff, Instant now) {
        if (collar.getLastPacketAt() != null && collar.getLastPacketAt().isBefore(cutoff)) {
            boolean openAlertExists = maintenanceAlertRepository
                    .findByCollarIdAndTypeAndResolvedFalse(collar.getId(), MaintenanceAlertType.TRANSMISSION_GAP)
                    .isPresent();

            if (!openAlertExists) {
                log.warn("AF-02: Transmission gap detected on collar {} (last packet at {}). Creating MaintenanceAlert.",
                        collar.getCode(), collar.getLastPacketAt());
                maintenanceAlertRepository.save(MaintenanceAlert.builder()
                        .collar(collar)
                        .type(MaintenanceAlertType.TRANSMISSION_GAP)
                        .createdAt(now)
                        .resolved(false)
                        .build());
                collar.setStatus(CollarStatus.TRANSMISSION_GAP);
                collarRepository.save(collar);
            }
        }
    }
}
