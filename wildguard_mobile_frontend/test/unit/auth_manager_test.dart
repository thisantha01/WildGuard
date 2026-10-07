import 'package:flutter_test/flutter_test.dart';
import 'package:wildguard_mobile_frontend/core/errors/app_exception.dart';
import 'package:wildguard_mobile_frontend/services/api_service.dart';
import 'package:wildguard_mobile_frontend/viewmodels/auth_manager.dart';

class FakeSuccessAuthApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> login(String username, String password) async {
    return {
      'token': 'mock-jwt-token-xyz',
      'userId': 'usr-123',
      'username': username,
      'email': 'ranger@wildguard.org',
      'fullName': 'Kamal Perera',
      'role': 'ROLE_RANGER',
      'badgeNumber': 'WG-001',
      'assignedPark': 'Yala National Park',
    };
  }

  @override
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String? badgeNumber,
    String? assignedPark,
    String role = 'RANGER',
  }) async {
    return {
      'token': 'mock-jwt-token-new',
      'userId': 'usr-999',
      'username': username,
      'email': email,
      'fullName': fullName,
      'role': 'ROLE_$role',
      'badgeNumber': badgeNumber,
      'assignedPark': assignedPark,
    };
  }
}

class FakeFailureAuthApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> login(String username, String password) async {
    throw NetworkSyncException('Login failed: Incorrect username or password');
  }

  @override
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String? badgeNumber,
    String? assignedPark,
    String role = 'RANGER',
  }) async {
    throw NetworkSyncException('Registration failed. User already exists.');
  }
}

void main() {
  group('AuthManager Unit Tests', () {
    test('login sets user details and token on successful response', () async {
      final fakeApi = FakeSuccessAuthApiService();
      final manager = AuthManager(apiService: fakeApi);

      expect(manager.isAuthenticated, isFalse);

      final result = await manager.login('ranger_kamal', 'Password123!');

      expect(result, isTrue);
      expect(manager.isAuthenticated, isTrue);
      expect(manager.currentUser?.username, 'ranger_kamal');
      expect(manager.token, 'mock-jwt-token-xyz');
      expect(manager.rangerDisplayName, 'Kamal Perera (WG-001)');
      expect(manager.parkName, 'Yala National Park');
    });

    test('login validates empty credentials without calling API', () async {
      final fakeApi = FakeSuccessAuthApiService();
      final manager = AuthManager(apiService: fakeApi);

      final result = await manager.login('', '');

      expect(result, isFalse);
      expect(manager.errorMessage, contains('Username and password are required'));
    });

    test('login sets errorMessage on failure', () async {
      final fakeApi = FakeFailureAuthApiService();
      final manager = AuthManager(apiService: fakeApi);

      final result = await manager.login('wrong_user', 'wrong_pass');

      expect(result, isFalse);
      expect(manager.isAuthenticated, isFalse);
      expect(manager.errorMessage, contains('Login failed'));
    });

    test('register successfully sets new user and token', () async {
      final fakeApi = FakeSuccessAuthApiService();
      final manager = AuthManager(apiService: fakeApi);

      final result = await manager.register(
        username: 'new_ranger',
        email: 'new@wildguard.org',
        password: 'Password123!',
        fullName: 'Nimal Silva',
        badgeNumber: 'WG-002',
        assignedPark: 'Wilpattu National Park',
      );

      expect(result, isTrue);
      expect(manager.isAuthenticated, isTrue);
      expect(manager.currentUser?.username, 'new_ranger');
      expect(manager.token, 'mock-jwt-token-new');
    });

    test('continueOffline enters guest mode for deep jungle logging', () {
      final fakeApi = FakeSuccessAuthApiService();
      final manager = AuthManager(apiService: fakeApi);

      manager.continueOffline();

      expect(manager.isOfflineGuestMode, isTrue);
      expect(manager.isAuthenticated, isTrue);
      expect(manager.rangerDisplayName, contains('Offline Mode'));
    });

    test('logout clears user, token, and guest mode', () async {
      final fakeApi = FakeSuccessAuthApiService();
      final manager = AuthManager(apiService: fakeApi);

      await manager.login('ranger_kamal', 'Password123!');
      expect(manager.isAuthenticated, isTrue);

      manager.logout();

      expect(manager.isAuthenticated, isFalse);
      expect(manager.currentUser, isNull);
      expect(manager.token, isNull);
    });
  });
}
