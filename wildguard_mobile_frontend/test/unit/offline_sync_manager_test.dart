import 'package:flutter_test/flutter_test.dart';
import 'package:wildguard_mobile_frontend/core/errors/app_exception.dart';
import 'package:wildguard_mobile_frontend/models/incident_model.dart';
import 'package:wildguard_mobile_frontend/models/incident_severity.dart';
import 'package:wildguard_mobile_frontend/models/incident_type.dart';
import 'package:wildguard_mobile_frontend/models/sync_status.dart';
import 'package:wildguard_mobile_frontend/repositories/incident_repository.dart';
import 'package:wildguard_mobile_frontend/services/connectivity_service.dart';
import 'package:wildguard_mobile_frontend/models/reserve_sector_model.dart';
import 'package:wildguard_mobile_frontend/services/location_service.dart';
import 'package:wildguard_mobile_frontend/viewmodels/offline_sync_manager.dart';

// Test Doubles (Mocks)
class FakeIncidentRepository implements IncidentRepository {
  final List<IncidentModel> storage = [];
  bool shouldThrowOnSync = false;

  @override
  Future<void> saveIncidentLocally(IncidentModel incident) async {
    storage.removeWhere((i) => i.localIncidentId == incident.localIncidentId);
    storage.add(incident);
  }

  @override
  Future<List<IncidentModel>> getAllIncidents() async {
    return List.from(storage);
  }

  @override
  Future<List<IncidentModel>> getPendingIncidents() async {
    return storage.where((i) => i.syncStatus == SyncStatus.pending).toList();
  }

  @override
  Future<Map<String, dynamic>> syncSingleIncident(IncidentModel incident) async {
    if (shouldThrowOnSync) {
      throw const NetworkSyncException('Server connection timed out');
    }
    return {
      'localIncidentId': incident.localIncidentId,
      'serverIncidentId': 'srv-${incident.localIncidentId}',
      'status': 'SYNCED',
      'duplicateFlag': false,
    };
  }

  @override
  Future<void> markIncidentAsSynced(
    String localId,
    String serverId, {
    bool? duplicateFlag,
  }) async {
    final index = storage.indexWhere((i) => i.localIncidentId == localId);
    if (index != -1) {
      storage[index] = storage[index].copyWith(
        syncStatus: SyncStatus.synced,
        serverIncidentId: serverId,
        duplicateFlag: duplicateFlag ?? false,
        syncedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> markIncidentAsFailed(String localId) async {
    final index = storage.indexWhere((i) => i.localIncidentId == localId);
    if (index != -1) {
      storage[index] = storage[index].copyWith(syncStatus: SyncStatus.failed);
    }
  }

  @override
  Future<List<IncidentModel>> fetchRemoteIncidentHistory() async => [];
}

class FakeLocationService extends LocationService {
  Map<String, double>? mockCoordinates;

  @override
  Future<Map<String, double>?> getCurrentCoordinates() async {
    return mockCoordinates;
  }
}

class FakeConnectivityService extends ConnectivityService {
  bool mockIsOnline = true;

  @override
  Future<bool> isOnline() async {
    return mockIsOnline;
  }
}

void main() {
  late FakeIncidentRepository repository;
  late FakeLocationService locationService;
  late FakeConnectivityService connectivityService;
  late OfflineSyncManager manager;

  setUp(() {
    repository = FakeIncidentRepository();
    locationService = FakeLocationService();
    connectivityService = FakeConnectivityService();

    manager = OfflineSyncManager(
      repository: repository,
      locationService: locationService,
      connectivityService: connectivityService,
    );
  });

  group('OfflineSyncManager Positive Path Tests', () {
    test('saveIncidentOffline should save locally with PENDING status and reset form', () async {
      // Given
      manager.setIncidentType(IncidentType.carcass);
      manager.setIncidentSeverity(IncidentSeverity.critical);
      manager.setCoordinates(6.3685, 81.5273);

      // When
      final success = await manager.saveIncidentOffline(
        description: 'Dead elephant discovered near electric fence',
      );

      // Then
      expect(success, isTrue);
      expect(manager.incidents.length, 1);
      final saved = manager.incidents.first;
      expect(saved.type, IncidentType.carcass);
      expect(saved.severity, IncidentSeverity.critical);
      expect(saved.description, 'Dead elephant discovered near electric fence');
      expect(saved.latitude, 6.3685);
      expect(saved.longitude, 81.5273);
      expect(saved.syncStatus, SyncStatus.pending);
      expect(manager.pendingCount, 1);
      expect(manager.syncedCount, 0);
      expect(manager.successMessage, isNotNull);

      // Form reset verified
      expect(manager.latitude, isNull);
      expect(manager.longitude, isNull);
    });

    test('syncPendingIncidents should upload all pending items and mark SYNCED when online', () async {
      // Given: 2 incidents saved offline
      manager.setCoordinates(6.3685, 81.5273);
      await manager.saveIncidentOffline(description: 'Snare found');
      manager.setCoordinates(6.3700, 81.5290);
      await manager.saveIncidentOffline(description: 'Tracks found');

      expect(manager.pendingCount, 2);
      connectivityService.mockIsOnline = true;

      // When
      final count = await manager.syncPendingIncidents();

      // Then
      expect(count, 2);
      expect(manager.pendingCount, 0);
      expect(manager.syncedCount, 2);
      expect(manager.incidents.every((i) => i.syncStatus == SyncStatus.synced), isTrue);
      expect(manager.incidents.first.serverIncidentId, startsWith('srv-loc-'));
    });

    test('dropPinOnOfflineMap should set fallback reserve coordinates and clear GPS lost', () {
      manager.dropPinOnOfflineMap();

      expect(manager.latitude, 6.3685);
      expect(manager.longitude, 81.5273);
      expect(manager.isGpsLost, isFalse);
    });
  });

  group('OfflineSyncManager Negative Path & Validation Tests', () {
    test('saveIncidentOffline should throw ValidationException when description is empty', () async {
      manager.setCoordinates(6.3685, 81.5273);

      expect(
        () => manager.saveIncidentOffline(description: '   '),
        throwsA(isA<ValidationException>()),
      );

      expect(manager.incidents.length, 0);
      expect(manager.errorMessage, contains('description cannot be empty'));
    });

    test('saveIncidentOffline should throw ValidationException when coordinates are missing', () async {
      expect(
        () => manager.saveIncidentOffline(description: 'Snare spotted'),
        throwsA(isA<ValidationException>()),
      );

      expect(manager.incidents.length, 0);
      expect(manager.errorMessage, contains('GPS coordinates are required'));
    });

    test('syncPendingIncidents should abort gracefully with error when device is offline', () async {
      // Given: Offline device with pending items
      manager.setCoordinates(6.3685, 81.5273);
      await manager.saveIncidentOffline(description: 'Poacher footprints');

      connectivityService.mockIsOnline = false;

      // When
      final count = await manager.syncPendingIncidents();

      // Then
      expect(count, 0);
      expect(manager.pendingCount, 1);
      expect(manager.errorMessage, contains('No internet connection'));
    });

    test('syncPendingIncidents should mark incident as FAILED when remote server errors out', () async {
      // Given: Pending incident but server fails
      manager.setCoordinates(6.3685, 81.5273);
      await manager.saveIncidentOffline(description: 'Gunshot heard');

      repository.shouldThrowOnSync = true;
      connectivityService.mockIsOnline = true;

      // When
      final count = await manager.syncPendingIncidents();

      // Then
      expect(count, 0);
      expect(manager.incidents.first.syncStatus, SyncStatus.failed);
    });

    test('syncPendingIncidents should return 0 and success message when pending list is empty', () async {
      connectivityService.mockIsOnline = true;
      final count = await manager.syncPendingIncidents();
      expect(count, 0);
      expect(manager.successMessage, contains('already synchronized'));
    });

    test('fetchLocation should update coordinates when GPS returns coordinates', () async {
      locationService.mockCoordinates = {'latitude': 6.5, 'longitude': 81.6};
      await manager.fetchLocation();
      expect(manager.latitude, 6.5);
      expect(manager.longitude, 81.6);
      expect(manager.isGpsLost, isFalse);
    });

    test('fetchLocation should set isGpsLost when GPS returns null', () async {
      locationService.mockCoordinates = null;
      await manager.fetchLocation();
      expect(manager.isGpsLost, isTrue);
    });

    test('clearMessages should reset error and success messages', () {
      manager.clearMessages();
      expect(manager.errorMessage, isNull);
      expect(manager.successMessage, isNull);
    });

    test('runBackgroundSyncCycle when online silently uploads pending payload and updates status to SYNCED', () async {
      connectivityService.mockIsOnline = true;
      manager.setCoordinates(6.37, 81.40);
      await manager.saveIncidentOffline(description: 'Trap spotted in forest');

      expect(manager.pendingCount, 1);
      expect(manager.incidents.first.syncStatus, SyncStatus.pending);

      final syncedCount = await manager.runBackgroundSyncCycle();

      expect(syncedCount, 1);
      expect(manager.pendingCount, 0);
      expect(manager.incidents.first.syncStatus, SyncStatus.synced);
      expect(manager.incidents.first.serverIncidentId, startsWith('srv-'));
    });

    test('runBackgroundSyncCycle when offline sleeps and leaves records as PENDING', () async {
      connectivityService.mockIsOnline = false;
      manager.setCoordinates(6.37, 81.40);
      await manager.saveIncidentOffline(description: 'Tracks in mud');

      expect(manager.pendingCount, 1);

      final syncedCount = await manager.runBackgroundSyncCycle();

      expect(syncedCount, 0);
      expect(manager.pendingCount, 1);
      expect(manager.incidents.first.syncStatus, SyncStatus.pending);
    });

    test('retrySingleIncident should mark FAILED incident as SYNCED when successful', () async {
      manager.setCoordinates(6.37, 81.40);
      await manager.saveIncidentOffline(description: 'Poacher hideout spotted');
      final incident = manager.incidents.first;
      await repository.markIncidentAsFailed(incident.localIncidentId);
      await manager.loadIncidents();
      expect(manager.incidents.first.syncStatus, SyncStatus.failed);

      connectivityService.mockIsOnline = true;
      final ok = await manager.retrySingleIncident(manager.incidents.first);

      expect(ok, isTrue);
      expect(manager.incidents.first.syncStatus, SyncStatus.synced);
      expect(manager.errorMessage, isNull);
    });

    test('setSectorLocation sets coordinates and records locationSource', () {
      manager.setSectorLocation('Menik River Crossing Beat', 6.3685, 81.5273);

      expect(manager.latitude, 6.3685);
      expect(manager.longitude, 81.5273);
      expect(manager.isGpsLost, isFalse);
      expect(manager.locationSource, 'Sector: Menik River Crossing Beat');
    });

    test('setSectorLocation with offset calculates and records landmark offset reference', () {
      manager.setSectorLocation('Trail Marker 14 (Menik River)', 6.3698, 81.5286, '200 meters North-East');

      expect(manager.latitude, 6.3698);
      expect(manager.longitude, 81.5286);
      expect(manager.isGpsLost, isFalse);
      expect(manager.locationSource, 'Landmark: Trail Marker 14 (Menik River) (Offset: 200 meters North-East)');
    });

    test('fetchLocation falls back to Last Known Location (LKL) when live GPS is denied', () async {
      // First, simulate successful GPS lock
      locationService.mockCoordinates = {'latitude': 6.3721, 'longitude': 81.4012};
      await manager.fetchLocation();
      expect(manager.isGpsLost, isFalse);
      expect(manager.locationSource, 'GPS Satellite Lock');

      // Second, simulate GPS signal drop under dense tree canopy
      locationService.mockCoordinates = null;
      await manager.fetchLocation();

      expect(manager.isGpsLost, isTrue);
      expect(manager.latitude, 6.3721);
      expect(manager.longitude, 81.4012);
      expect(manager.locationSource, contains('Last Known Location (LKL)'));
    });
  });

  group('ReserveSectorModel Geodetic Offset Tests', () {
    test('computeOffsetCoordinates calculates accurate spherical geodetic offset for 200m North-East', () {
      const baseLat = 6.3685;
      const baseLon = 81.5273;
      final result = ReserveSectorModel.computeOffsetCoordinates(
        baseLat: baseLat,
        baseLon: baseLon,
        distanceMeters: 200.0,
        direction: 'North-East',
      );

      // In North-East, latitude and longitude should both increase
      expect(result['latitude']!, greaterThan(baseLat));
      expect(result['longitude']!, greaterThan(baseLon));
      // Delta should be approximately 200m * cos(45) / 111111 ~= 0.00127 degrees
      expect((result['latitude']! - baseLat).abs(), closeTo(0.00127, 0.0002));
    });

    test('computeOffsetCoordinates returns base coordinates when distance is 0', () {
      final result = ReserveSectorModel.computeOffsetCoordinates(
        baseLat: 6.2715,
        baseLon: 81.4428,
        distanceMeters: 0.0,
        direction: 'North',
      );

      expect(result['latitude'], 6.2715);
      expect(result['longitude'], 81.4428);
    });
  });
}

