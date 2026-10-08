import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/app_exception.dart';
import '../models/user_auth_model.dart';
import '../services/api_service.dart';

/// ViewModel managing Ranger authentication state, JWT tokens, and user profile.
class AuthManager extends ChangeNotifier {
  final ApiService apiService;
  static const String _sessionKey = 'wildguard_auth_user_session';

  UserAuthModel? _currentUser;
  bool _isLoading = false;
  bool _isOfflineGuestMode = false;
  String? _errorMessage;

  AuthManager({required this.apiService});

  UserAuthModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isOfflineGuestMode => _isOfflineGuestMode;
  bool get isAuthenticated => _currentUser != null || _isOfflineGuestMode;
  String? get token => _currentUser?.token;
  String? get errorMessage => _errorMessage;

  Future<bool> tryRestoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> data =
            jsonDecode(raw) as Map<String, dynamic>;
        _currentUser = UserAuthModel.fromJson(data);
        if (_currentUser?.token != null && _currentUser!.token.isNotEmpty) {
          apiService.setAuthToken(_currentUser!.token);
        }
        _isOfflineGuestMode = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ [AUTH] Failed to restore session from prefs: $e');
    }
    return false;
  }

  Future<void> _persistSession(UserAuthModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('⚠️ [AUTH] Failed to save session to prefs: $e');
    }
  }

  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (e) {
      debugPrint('⚠️ [AUTH] Failed to remove session from prefs: $e');
    }
  }

  String get rangerDisplayName {
    if (_currentUser != null) {
      final badge = _currentUser!.badgeNumber != null
          ? ' (${_currentUser!.badgeNumber})'
          : '';
      return '${_currentUser!.fullName}$badge';
    }
    return 'Field Ranger (Offline Mode)';
  }

  String get parkName {
    return _currentUser?.assignedPark ?? 'Field Reserve';
  }

  /// Attempts login using credentials.
  Future<bool> login(String username, String password) async {
    if (username.trim().isEmpty || password.trim().isEmpty) {
      _errorMessage = 'Username and password are required.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await apiService.login(username, password);
      _currentUser = UserAuthModel.fromJson(response);
      _isOfflineGuestMode = false;
      _isLoading = false;
      await _persistSession(_currentUser!);
      notifyListeners();
      return true;
    } on NetworkSyncException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Registers a new Ranger account and automatically logs in.
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String? badgeNumber,
    String? assignedPark,
    String? phoneNumber,
    String role = 'RANGER',
  }) async {
    if (username.trim().isEmpty ||
        email.trim().isEmpty ||
        password.trim().isEmpty ||
        fullName.trim().isEmpty) {
      _errorMessage = 'Please fill in all mandatory fields.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await apiService.register(
        username: username,
        email: email,
        password: password,
        fullName: fullName,
        badgeNumber: badgeNumber,
        assignedPark: assignedPark,
        phoneNumber: phoneNumber,
        role: role,
      );
      _currentUser = UserAuthModel.fromJson(response);
      _isOfflineGuestMode = false;
      _isLoading = false;
      await _persistSession(_currentUser!);
      notifyListeners();
      return true;
    } on NetworkSyncException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Registration error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Allows a Ranger deep in the forest without connection to work in offline guest mode.
  void continueOffline() {
    _isOfflineGuestMode = true;
    _currentUser = null;
    _errorMessage = null;
    _clearPersistedSession();
    notifyListeners();
  }

  /// Logs out the user and clears tokens.
  void logout() {
    _currentUser = null;
    _isOfflineGuestMode = false;
    apiService.setAuthToken(null);
    _errorMessage = null;
    _clearPersistedSession();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Fetches next available badge ID dynamically from backend
  Future<String> fetchNextBadgeNumber(String role) async {
    return await apiService.fetchNextBadgeNumber(role);
  }
}
