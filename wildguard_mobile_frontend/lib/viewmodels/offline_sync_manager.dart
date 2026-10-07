import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
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
  String? _errorMessage;
  String? _successMessage;

  // Form State
  IncidentType _selectedType = IncidentType.snare;
  IncidentSeverity _selectedSeverity = IncidentSeverity.high;
  double? _latitude;
  double? _longitude;
  bool _isGpsLost = false;
  String? _photoPath;
  String? _photoBase64;

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
  int get pendingCount => _incidents.where((i) => i.syncStatus == SyncStatus.pending).length;
  int get syncedCount => _incidents.where((i) => i.syncStatus == SyncStatus.synced).length;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  IncidentType get selectedType => _selectedType;
  IncidentSeverity get selectedSeverity => _selectedSeverity;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  bool get isGpsLost => _isGpsLost;
  String? get photoPath => _photoPath;
  String? get photoBase64 => _photoBase64;

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
    notifyListeners();
  }

  /// Clears transient snackbar messages.
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Loads all incidents from local SQLite database.
  Future<void> loadIncidents() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _incidents = await repository.getAllIncidents();
    } catch (e) {
      _errorMessage = 'Failed to load offline incidents: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches real-time GPS coordinates. Falls back to "GPS Lost" if sensors/offline block reception.
  Future<void> fetchLocation() async {
    final coords = await _locationService.getCurrentCoordinates();
    if (coords != null) {
      _latitude = coords['latitude'];
      _longitude = coords['longitude'];
      _isGpsLost = false;
    } else {
      _isGpsLost = true;
    }
    notifyListeners();
  }

  /// Simulates / drops pin on offline map when GPS fails in dense jungle.
  void dropPinOnOfflineMap() {
    final fallback = _locationService.getFallbackReserveCoordinates();
    _latitude = fallback['latitude'];
    _longitude = fallback['longitude'];
    _isGpsLost = false;
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
        final bytes = await File(image.path).readAsBytes();
        _photoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to capture photo: $e';
      notifyListeners();
    }
  }

  /// Resets current form fields after saving.
  void resetForm() {
    _selectedType = IncidentType.snare;
    _selectedSeverity = IncidentSeverity.high;
    _latitude = null;
    _longitude = null;
    _isGpsLost = false;
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
      _successMessage = 'Incident saved offline successfully.';
      resetForm();
      await loadIncidents();
      return true;
    } catch (e) {
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
        } catch (_) {
          await repository.markIncidentAsFailed(incident.localIncidentId);
        }
      }

      _successMessage = 'Successfully synced $syncedCount incident(s) with base station!';
      await loadIncidents();
    } catch (e) {
      _errorMessage = 'Error during synchronization: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }

    return syncedCount;
  }
}
