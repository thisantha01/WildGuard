import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/incident_model.dart';
import '../models/incident_severity.dart';
import '../models/incident_type.dart';
import '../models/sync_status.dart';
import '../repositories/incident_repository.dart';
import '../services/connectivity_service.dart';
import '../services/location_service.dart';

/// MVVM ViewModel / Controller managing Offline Incident Logging and Background Sync.
class OfflineSyncManager extends ChangeNotifier {
  final IncidentRepository repository;
  final LocationService _locationService;
  final ConnectivityService _connectivityService;
  final ImagePicker _imagePicker;

  List<IncidentModel> _incidents = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isOnline = false;
  String? _errorMessage;
  String? _successMessage;

  // Form State
  IncidentType _selectedType = IncidentType.snare;
  IncidentSeverity _selectedSeverity = IncidentSeverity.high;
  double? _latitude;
  double? _longitude;
  bool _isGpsLost = false;
  bool _isLocating = false;
  String? _photoPath;
  String? _photoBase64;
  IncidentModel? _lastSavedIncident;
  Timer? _backgroundSyncTimer;
  StreamSubscription<bool>? _connectivitySubscription;

  OfflineSyncManager({
    required this.repository,
    LocationService? locationService,
    ConnectivityService? connectivityService,
    ImagePicker? imagePicker,
  })  : _locationService = locationService ?? LocationService(),
        _connectivityService = connectivityService ?? ConnectivityService(),
        _imagePicker = imagePicker ?? ImagePicker();

  // Getters
  List<IncidentModel> get incidents => List.unmodifiable(_incidents);
  int get pendingCount => _incidents.where((i) => i.syncStatus == SyncStatus.pending || i.syncStatus == SyncStatus.failed).length;
  int get syncedCount => _incidents.where((i) => i.syncStatus == SyncStatus.synced).length;
  int get failedCount => _incidents.where((i) => i.syncStatus == SyncStatus.failed).length;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isLocating => _isLocating;
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  IncidentModel? get lastSavedIncident => _lastSavedIncident;

  /// Checks device network state and updates online indicator.
  Future<bool> checkConnectivity() async {
    try {
      final online = await _connectivityService.isOnline();
      if (_isOnline != online) {
        _isOnline = online;
        notifyListeners();
      }
      return _isOnline;
    } catch (_) {
      _isOnline = false;
      notifyListeners();
      return false;
    }
  }

  /// Sets online state manually (for unit testing or mock network toggling).
  void setOnlineStatus(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
  }

  IncidentType get selectedType => _selectedType;
  IncidentSeverity get selectedSeverity => _selectedSeverity;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  bool get isGpsLost => _isGpsLost;
  String? get photoPath => _photoPath;
  String? get photoBase64 => _photoBase64;

  String? _locationSource;
  String? get locationSource => _locationSource;

  // Last Known Location (LKL) telemetry cache
  double? _lastKnownLatitude;
  double? _lastKnownLongitude;
  DateTime? _lastKnownLocationTime;

  double? get lastKnownLatitude => _lastKnownLatitude;
  double? get lastKnownLongitude => _lastKnownLongitude;
  DateTime? get lastKnownLocationTime => _lastKnownLocationTime;

  int get lastKnownMinutesAgo {
    if (_lastKnownLocationTime == null) return 10;
    final diff = DateTime.now().difference(_lastKnownLocationTime!).inMinutes;
    return diff > 0 ? diff : 5;
  }

  // Setters for Form UI
  void setIncidentType(IncidentType type) {
    _selectedType = type;
    notifyListeners();
  }

  void setIncidentSeverity(IncidentSeverity severity) {
    _selectedSeverity = severity;
    notifyListeners();
  }

  /// Sets manual coordinates (used for testing or custom map pins).
  void setCoordinates(double lat, double lon) {
    _latitude = lat;
    _longitude = lon;
    _isGpsLost = false;
    _locationSource = 'Map Tap Pin';
    notifyListeners();
  }

  /// Sets location based on pre-mapped reserve sector / landmark (HCI Fallback) with optional offset.
  void setSectorLocation(String sectorName, double lat, double lon, [String? offset]) {
    _latitude = lat;
    _longitude = lon;
    _isGpsLost = false;
    if (offset != null && offset.isNotEmpty && offset != '0m') {
      _locationSource = 'Landmark: $sectorName (Offset: $offset)';
    } else {
      _locationSource = 'Sector: $sectorName';
    }
    notifyListeners();
  }

  /// Manually toggles GPS lost state (for simulation / testing under dense canopy).
  void toggleGpsLost() {
    _isGpsLost = !_isGpsLost;
    if (_isGpsLost) {
      _locationSource = 'GPS Lost (Signal Obstructed)';
    } else {
      _locationSource = 'GPS Satellite Lock';
    }
    notifyListeners();
  }

  /// Sets GPS lost state explicitly.
  void setGpsLost(bool lost) {
    if (_isGpsLost != lost) {
      _isGpsLost = lost;
      if (lost) {
        _locationSource = 'GPS Lost (Signal Obstructed)';
      } else {
        _locationSource = 'GPS Satellite Lock';
      }
      notifyListeners();
    }
  }

  /// Clears transient snackbar messages.
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Loads all incidents from local SQLite database, optionally syncing remote history from backend when online.
  Future<void> loadIncidents({bool fetchRemote = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (fetchRemote) {
        final isOnline = await _connectivityService.isOnline();
        if (isOnline) {
          try {
            await repository.fetchRemoteIncidentHistory();
          } catch (_) {
            // Graceful fallback if backend is unreachable or offline
          }
        }
      }
      _incidents = await repository.getAllIncidents();
    } catch (e) {
      _errorMessage = 'Failed to load offline incidents: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches real-time GPS coordinates. Falls back to "Last Known Location (LKL)" if sensors/canopy block reception.
  Future<bool> fetchLocation() async {
    _isLocating = true;
    notifyListeners();

    try {
      final coords = await _locationService.getCurrentCoordinates();
      if (coords != null) {
        _latitude = coords['latitude'];
        _longitude = coords['longitude'];
        _lastKnownLatitude = _latitude;
        _lastKnownLongitude = _longitude;
        _lastKnownLocationTime = DateTime.now();
        _isGpsLost = false;
        _locationSource = 'GPS Satellite Lock';
        return true;
      } else {
        _isGpsLost = true;
        // Last Known Location (LKL) Fallback
        _latitude = _lastKnownLatitude ?? AppConstants.defaultReserveLatitude;
        _longitude = _lastKnownLongitude ?? AppConstants.defaultReserveLongitude;
        if (_lastKnownLatitude == null) {
          _lastKnownLatitude = _latitude;
          _lastKnownLongitude = _longitude;
          _lastKnownLocationTime = DateTime.now().subtract(const Duration(minutes: 10));
        }
        _locationSource = 'Last Known Location (LKL) - ${lastKnownMinutesAgo}m ago';
        return false;
      }
    } finally {
      _isLocating = false;
      notifyListeners();
    }
  }

  /// Simulates / drops pin on offline map when GPS fails in dense jungle.
  void dropPinOnOfflineMap() {
    final fallback = _locationService.getFallbackReserveCoordinates();
    _latitude = fallback['latitude'];
    _longitude = fallback['longitude'];
    _isGpsLost = false;
    _isLocating = false;
    _locationSource = 'Offline Reserve Pin';
    notifyListeners();
  }

  /// Picks photo from camera or gallery and converts to base64 for offline storage.
  Future<void> pickPhoto(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        _photoPath = image.path;
        final bytes = await image.readAsBytes();
        _photoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to capture photo: $e';
      notifyListeners();
    }
  }

  /// Clears attached evidence photo.
  void clearPhoto() {
    _photoPath = null;
    _photoBase64 = null;
    notifyListeners();
  }

  /// Resets current form fields after saving.
  void resetForm() {
    _selectedType = IncidentType.snare;
    _selectedSeverity = IncidentSeverity.high;
    _latitude = null;
    _longitude = null;
    _isGpsLost = false;
    _locationSource = null;
    _photoPath = null;
    _photoBase64 = null;
    notifyListeners();
  }

  /// Validates inputs and saves the incident locally with status 'PENDING'.
  Future<bool> saveIncidentOffline({required String description}) async {
    _errorMessage = null;
    _successMessage = null;

    final trimmedDescription = description.trim();
    if (trimmedDescription.isEmpty) {
      _errorMessage = 'Incident description cannot be empty.';
      notifyListeners();
      throw const ValidationException('Incident description cannot be empty.');
    }

    if (_latitude == null || _longitude == null) {
      _errorMessage = 'GPS coordinates are required. Please drop a pin or enable GPS.';
      notifyListeners();
      throw const ValidationException('GPS coordinates are required.');
    }

    final String localId = 'loc-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(99999)}';

    final incident = IncidentModel(
      localIncidentId: localId,
      type: _selectedType,
      severity: _selectedSeverity,
      description: trimmedDescription,
      latitude: _latitude!,
      longitude: _longitude!,
      photoPath: _photoPath,
      photoBase64: _photoBase64,
      timestamp: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    try {
      await repository.saveIncidentLocally(incident);
      _lastSavedIncident = incident;
      debugPrint('💾 [OFFLINE STORAGE] Incident successfully saved to device!');
      debugPrint('   • Local ID: ${incident.localIncidentId}');
      debugPrint('   • Type: ${incident.type.displayName}');
      debugPrint('   • Severity: ${incident.severity.displayName}');
      debugPrint('   • Description: ${incident.description}');
      debugPrint('   • Coordinates: (${incident.latitude}, ${incident.longitude})');
      debugPrint('   • Sync Status: ${incident.syncStatus.code}');
      _successMessage = 'Incident saved offline successfully.';
      resetForm();
      await loadIncidents(fetchRemote: false);
      return true;
    } catch (e) {
      debugPrint('❌ [OFFLINE STORAGE ERROR] Failed to save offline: $e');
      _errorMessage = 'Failed to save offline: $e';
      notifyListeners();
      return false;
    }
  }

  /// Synchronizes all 'PENDING' incidents to the Spring Boot backend when online.
  Future<int> syncPendingIncidents() async {
    _isSyncing = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    int syncedCount = 0;

    try {
      final isOnline = await _connectivityService.isOnline();
      if (!isOnline) {
        _errorMessage = 'No internet connection. Device is currently offline.';
        _isSyncing = false;
        notifyListeners();
        return 0;
      }

      final pendingList = await repository.getPendingIncidents();
      if (pendingList.isEmpty) {
        _successMessage = 'All incidents are already synchronized!';
        _isSyncing = false;
        notifyListeners();
        return 0;
      }

      String? lastFailureMessage;
      for (final incident in pendingList) {
        try {
          final result = await repository.syncSingleIncident(incident);
          final serverId = result['serverIncidentId'] as String?;
          final duplicateFlag = result['duplicateFlag'] as bool? ?? false;

          await repository.markIncidentAsSynced(
            incident.localIncidentId,
            serverId ?? 'synced-server-id',
            duplicateFlag: duplicateFlag,
          );
          syncedCount++;
        } on NetworkSyncException catch (e) {
          debugPrint('❌ [SYNC FAILED] ${incident.localIncidentId}: ${e.message}');
          lastFailureMessage = e.message;
          final isAuthError = e.message.toLowerCase().contains('authentication required') ||
              e.message.toLowerCase().contains('401');
          if (!isAuthError) {
            await repository.markIncidentAsFailed(incident.localIncidentId);
          }
        } catch (e) {
          debugPrint('❌ [SYNC ERROR] ${incident.localIncidentId}: $e');
          lastFailureMessage = 'Network error: $e';
          await repository.markIncidentAsFailed(incident.localIncidentId);
        }
      }

      if (syncedCount > 0) {
        _successMessage = 'Successfully synced $syncedCount incident(s) with base station!';
      }
      if (lastFailureMessage != null) {
        _errorMessage = lastFailureMessage;
      }
      await loadIncidents();
    } catch (e) {
      _errorMessage = 'Error during synchronization: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }

    return syncedCount;
  }

  /// Retries syncing a single failed incident immediately.
  Future<bool> retrySingleIncident(IncidentModel incident) async {
    _isSyncing = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final isOnline = await _connectivityService.isOnline();
      if (!isOnline) {
        _errorMessage = 'No internet connection. Please check your network to sync.';
        notifyListeners();
        return false;
      }

      final result = await repository.syncSingleIncident(incident);
      final serverId = result['serverIncidentId'] as String?;
      final duplicateFlag = result['duplicateFlag'] as bool? ?? false;

      await repository.markIncidentAsSynced(
        incident.localIncidentId,
        serverId ?? 'srv-${incident.localIncidentId}',
        duplicateFlag: duplicateFlag,
      );
      _successMessage = 'Incident successfully synchronized!';
      await loadIncidents();
      return true;
    } on NetworkSyncException catch (e) {
      _errorMessage = e.message;
      final isAuthError = e.message.toLowerCase().contains('authentication required') ||
          e.message.toLowerCase().contains('401');
      if (!isAuthError) {
        await repository.markIncidentAsFailed(incident.localIncidentId);
      }
      return false;
    } catch (e) {
      _errorMessage = 'Network error: $e';
      await repository.markIncidentAsFailed(incident.localIncidentId);
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Starts the asynchronous background sync worker.
  /// Continuously checks network state and silently synchronizes pending incidents.
  void startBackgroundSyncWorker({Duration interval = const Duration(seconds: 15)}) {
    _backgroundSyncTimer?.cancel();
    _connectivitySubscription?.cancel();

    // Listen for connectivity changes (e.g., Ranger coming into range of mobile tower/Wi-Fi)
    _connectivitySubscription = _connectivityService.onConnectivityChanged.listen((isOnline) {
      if (_isOnline != isOnline) {
        _isOnline = isOnline;
        notifyListeners();
      }
      if (isOnline) {
        debugPrint('📡 [BACKGROUND SYNC WORKER] Online connection detected! Triggering silent upload...');
        runBackgroundSyncCycle();
      }
    });

    // Automated periodic polling cycle
    _backgroundSyncTimer = Timer.periodic(interval, (_) async {
      await runBackgroundSyncCycle();
    });
  }

  /// Cancels background sync polling worker and connectivity listener.
  void stopBackgroundSyncWorker() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Asynchronous Background Process: The System's background Sync Worker continuously checks the network state.
  /// • If Online: The worker silently uploads the payload to the Backend API. Upon receiving a 200 OK response,
  ///   it updates the local database flag to sync_status = "SYNCED".
  /// • If Offline: The worker sleeps and the record remains PENDING for the next automated polling cycle.
  Future<int> runBackgroundSyncCycle() async {
    if (_isSyncing) return 0;

    try {
      final isOnline = await _connectivityService.isOnline();
      if (_isOnline != isOnline) {
        _isOnline = isOnline;
        notifyListeners();
      }
      if (!isOnline) {
        debugPrint('📡 [BACKGROUND SYNC WORKER] Device is OFFLINE. Worker sleeps. Records remain PENDING.');
        return 0;
      }

      final pendingList = await repository.getPendingIncidents();
      if (pendingList.isEmpty) {
        return 0;
      }

      debugPrint('📡 [BACKGROUND SYNC WORKER] Online connection confirmed! Silently syncing ${pendingList.length} incident(s)...');
      int silentSynced = 0;

      for (final incident in pendingList) {
        try {
          final result = await repository.syncSingleIncident(incident);
          final serverId = result['serverIncidentId'] as String?;
          final duplicateFlag = result['duplicateFlag'] as bool? ?? false;

          await repository.markIncidentAsSynced(
            incident.localIncidentId,
            serverId ?? 'srv-${incident.localIncidentId}',
            duplicateFlag: duplicateFlag,
          );
          silentSynced++;
          debugPrint('   ✓ [BACKGROUND SYNC WORKER] 200 OK received for [${incident.localIncidentId}]. Updated sync_status = "SYNCED".');
        } catch (e) {
          debugPrint('   ⚠ [BACKGROUND SYNC WORKER] Sync retry for [${incident.localIncidentId}]: $e');
        }
      }

      if (silentSynced > 0) {
        await loadIncidents();
      }
      return silentSynced;
    } catch (e) {
      debugPrint('📡 [BACKGROUND SYNC WORKER] Exception during polling cycle: $e');
      return 0;
    }
  }

  @override
  void dispose() {
    stopBackgroundSyncWorker();
    super.dispose();
  }
}
