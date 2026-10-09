package com.wildlife.uc02.seed;

import com.wildguard.backend.modules.user.model.Role;
import com.wildguard.backend.modules.user.model.User;
import com.wildguard.backend.modules.user.repository.UserRepository;
import com.wildlife.uc02.entity.*;
import com.wildlife.uc02.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

/**
 * Seed data runner for UC02.
 * Initializes Yala National Park, ParkConfig, elephants, collars, geofences,
 * settlements, rangers, CLO, and historical resolved alerts.
 */
@Slf4j
@Component
@org.springframework.context.annotation.Profile("!test")
@RequiredArgsConstructor
public class Uc02DataSeeder implements CommandLineRunner {

    private final ParkRepository parkRepository;
    private final AnimalRepository animalRepository;
    private final CollarRepository collarRepository;
    private final GeofenceZoneRepository zoneRepository;
    private final SettlementRepository settlementRepository;
    private final RangerStatusRepository rangerStatusRepository;
    private final CloRepository cloRepository;
    private final AlertRepository alertRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final Clock clock;

    @Override
    public void run(String... args) {
        try {
            Optional<Park> existingPark = parkRepository.findByName("Yala National Park");
            if (existingPark.isPresent()) {
                Park p = existingPark.get();
                zoneRepository.findAll().forEach(z -> {
                    if (z.getParkId() == null) {
                        z.setParkId(p.getId());
                        zoneRepository.save(z);
                    }
                });
                settlementRepository.findAll().forEach(s -> {
                    if (s.getParkId() == null) {
                        s.setParkId(p.getId());
                        settlementRepository.save(s);
                    }
                });
                log.info("UC02 seed data already loaded (verified zone & settlement bindings).");
                return;
            }

        log.info("Seeding UC02 data for Yala National Park...");
        Instant now = Instant.now(clock);

        // 1. Park & ParkConfig
        ParkConfig config = ParkConfig.builder()
                .expectedTelemetryIntervalMin(15)
                .transmissionGapMin(30)
                .groupingRadiusM(500)
                .rangerSearchRadiusKm(30)
                .ackTimeoutMin(5)
                .dispatchTimeoutMin(10)
                .notificationRetryIntervalMin(5)
                .notificationRetryLimitMin(60)
                .reEntryConsecutivePackets(2)
                .safetyBufferM(50)
                .lowBatteryPercent(20)
                .rangerLocationStaleMin(30)
                .averageSpeedKmh(40)
                .build();

        Park park = parkRepository.save(Park.builder()
                .name("Yala National Park")
                .config(config)
                .build());

        // 2. Animal & Collar
        Animal rajah = animalRepository.save(Animal.builder()
                .name("Rajah")
                .tagId("ELE-024")
                .species("Sri Lankan Elephant")
                .sex("MALE")
                .build());

        Collar collar = collarRepository.save(Collar.builder()
                .code("COL-024")
                .animal(rajah)
                .batteryPercent(85)
                .lastPacketAt(now)
                .status(CollarStatus.ACTIVE)
                .build());

        // 3. Settlement: Ihatikulama (~600m from farmland breach)
        settlementRepository.save(Settlement.builder()
                .park(park)
                .parkId(park.getId())
                .name("Ihatikulama")
                .lat(6.3750)
                .lng(81.5050)
                .build());

        // 4. Geofence Zones
        // FARMLAND zone (Sector 04) near 6.37N, 81.50E
        zoneRepository.save(GeofenceZone.builder()
                .park(park)
                .parkId(park.getId())
                .name("Yala Sector 04 Farmland")
                .type(ZoneType.FARMLAND)
                .active(true)
                .valid(true)
                .polygon(List.of(
                        new GeoPoint(6.3680, 81.4980),
                        new GeoPoint(6.3720, 81.4980),
                        new GeoPoint(6.3720, 81.5020),
                        new GeoPoint(6.3680, 81.5020)
                ))
                .build());

        // ROAD zone
        zoneRepository.save(GeofenceZone.builder()
                .park(park)
                .parkId(park.getId())
                .name("Main Park Road Corridor")
                .type(ZoneType.ROAD)
                .active(true)
                .valid(true)
                .polygon(List.of(
                        new GeoPoint(6.3600, 81.4900),
                        new GeoPoint(6.3650, 81.4900),
                        new GeoPoint(6.3650, 81.4950),
                        new GeoPoint(6.3600, 81.4950)
                ))
                .build());

        // VILLAGE zone
        zoneRepository.save(GeofenceZone.builder()
                .park(park)
                .parkId(park.getId())
                .name("Ihatikulama Village Buffer")
                .type(ZoneType.VILLAGE)
                .active(true)
                .valid(true)
                .polygon(List.of(
                        new GeoPoint(6.3730, 81.5030),
                        new GeoPoint(6.3780, 81.5030),
                        new GeoPoint(6.3780, 81.5080),
                        new GeoPoint(6.3730, 81.5080)
                ))
                .build());

        // Invalid polygon for EF-06 testing (<3 points)
        zoneRepository.save(GeofenceZone.builder()
                .park(park)
                .name("Defective Border Sensor Polygon")
                .type(ZoneType.FARMLAND)
                .active(true)
                .valid(false)
                .polygon(List.of(
                        new GeoPoint(6.3800, 81.5100),
                        new GeoPoint(6.3810, 81.5110)
                ))
                .build());

        // 5. Users & Rangers
        String encodedPassword = passwordEncoder.encode("password123");

        // Primary Ranger: Saman P (R-07) - AVAILABLE, ~4.8 km from breach
        User samanUser = getOrCreateUser("saman_p", "saman@wildguard.gov.lk", "Saman P", "R-07", Role.ROLE_RANGER, park.getName(), encodedPassword);
        rangerStatusRepository.save(RangerStatus.builder()
                .userId(samanUser.getId())
                .name("Saman P")
                .unitCode("R-07")
                .parkId(park.getId())
                .availability(RangerAvailability.AVAILABLE)
                .lastLat(6.3400)
                .lastLng(81.5200)
                .lastLocationAt(now)
                .build());

        // Ranger 2: Kamal D (R-08) - Stale location (>30 min ago)
        User kamalUser = getOrCreateUser("kamal_d", "kamal@wildguard.gov.lk", "Kamal D", "R-08", Role.ROLE_RANGER, park.getName(), encodedPassword);
        rangerStatusRepository.save(RangerStatus.builder()
                .userId(kamalUser.getId())
                .name("Kamal D")
                .unitCode("R-08")
                .parkId(park.getId())
                .availability(RangerAvailability.AVAILABLE)
                .lastLat(6.3450)
                .lastLng(81.5150)
                .lastLocationAt(now.minusSeconds(45 * 60L)) // 45 min stale
                .build());

        // Ranger 3: Nimal S (R-09) - Far away (>30 km)
        User nimalUser = getOrCreateUser("nimal_s", "nimal@wildguard.gov.lk", "Nimal S", "R-09", Role.ROLE_RANGER, park.getName(), encodedPassword);
        rangerStatusRepository.save(RangerStatus.builder()
                .userId(nimalUser.getId())
                .name("Nimal S")
                .unitCode("R-09")
                .parkId(park.getId())
                .availability(RangerAvailability.AVAILABLE)
                .lastLat(6.7000)
                .lastLng(81.9000)
                .lastLocationAt(now)
                .build());

        // Manager User
        User managerUser = getOrCreateUser("manager1", "manager@wildguard.gov.lk", "Park Manager Silva", "M-01", Role.ROLE_MANAGER, park.getName(), encodedPassword);

        // CLO User & Entity
        User cloUser = getOrCreateUser("clo1", "clo@wildguard.gov.lk", "Liaison Officer Perera", "C-01", Role.ROLE_LIAISON, park.getName(), encodedPassword);
        cloRepository.save(CommunityLiaisonOfficer.builder()
                .userId(cloUser.getId())
                .name("Liaison Officer Perera")
                .parkId(park.getId())
                .build());

        // Technician User (using ROLE_MANAGER for access compatibility)
        getOrCreateUser("technician1", "tech@wildguard.gov.lk", "Technician Fernando", "T-01", Role.ROLE_MANAGER, park.getName(), encodedPassword);

        // 6. Historic RESOLVED alerts (within 1 km, within last 90 days for conflict history rule)
        alertRepository.save(Alert.builder()
                .displayCode("ALT-0001")
                .animal(rajah)
                .parkId(park.getId())
                .status(AlertStatus.RESOLVED)
                .threatLevel(ThreatLevel.MODERATE)
                .lat(6.3700)
                .lng(81.5000)
                .breachTime(now.minusSeconds(10 * 86400L))
                .resolvedAt(now.minusSeconds(10 * 86400L - 3600))
                .assignedRangerId(samanUser.getId())
                .build());

        alertRepository.save(Alert.builder()
                .displayCode("ALT-0002")
                .animal(rajah)
                .parkId(park.getId())
                .status(AlertStatus.RESOLVED)
                .threatLevel(ThreatLevel.HIGH)
                .lat(6.3710)
                .lng(81.5010)
                .breachTime(now.minusSeconds(25 * 86400L))
                .resolvedAt(now.minusSeconds(25 * 86400L - 7200))
                .assignedRangerId(samanUser.getId())
                .build());

        log.info("UC02 seed data initialization completed successfully.");
        } catch (Exception ex) {
            log.warn("MongoDB database unavailable during UC02 seed execution (skipping): {}", ex.getMessage());
        }
    }

    private User getOrCreateUser(String username, String email, String fullName, String badge, Role role, String parkName, String encodedPassword) {
        return userRepository.findByUsername(username).orElseGet(() ->
                userRepository.save(User.builder()
                        .username(username)
                        .email(email)
                        .fullName(fullName)
                        .badgeNumber(badge)
                        .role(role)
                        .assignedPark(parkName)
                        .password(encodedPassword)
                        .active(true)
                        .build())
        );
    }
}
