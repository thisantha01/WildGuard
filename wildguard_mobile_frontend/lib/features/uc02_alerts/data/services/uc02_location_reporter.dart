import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../services/connectivity_service.dart';
import '../../../../services/location_service.dart';
import '../datasources/uc02_remote_datasource.dart';

/// Periodically reports the ranger's GPS position and sends heartbeats
/// to the backend while the app is open and online.
///
/// Reuses the existing [LocationService] and [ConnectivityService].
class Uc02LocationReporter {
  final LocationService _locationService;
  final ConnectivityService _connectivityService;
  final Uc02RemoteDataSource _remote;
  final String? Function() _tokenGetter;

  static const Duration _interval = Duration(minutes: 1);

  Timer? _timer;

  Uc02LocationReporter({
    required LocationService locationService,
    required ConnectivityService connectivityService,
    required Uc02RemoteDataSource remote,
    required String? Function() tokenGetter,
  })  : _locationService = locationService,
        _connectivityService = connectivityService,
        _remote = remote,
        _tokenGetter = tokenGetter;

  /// Starts the periodic location/heartbeat reporting.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _report());
    // Fire immediately
    _report();
  }

  /// Stops the periodic reporting.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _report() async {
    final token = _tokenGetter();
    if (token == null || token.isEmpty) return;

    final online = await _connectivityService.isOnline();
    if (!online) return;

    try {
      // Heartbeat (best effort)
      await _remote.heartbeat(token);

      // Location update (best effort)
      final coords = await _locationService.getCurrentCoordinates();
      if (coords != null) {
        await _remote.updateLocation(
          coords['latitude']!,
          coords['longitude']!,
          token,
        );
      }
    } catch (e) {
      debugPrint('[UC02 LocationReporter] Error: $e');
    }
  }
}
