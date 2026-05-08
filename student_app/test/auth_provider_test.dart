import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/providers/auth_provider.dart';
import 'package:student_app/services/api_service.dart';

class _FakeApiService extends ApiService {
  _FakeApiService({
    this.token,
    this.profileResponse = const {'success': false},
    this.profileCompleter,
  });

  final String? token;
  final Map<String, dynamic> profileResponse;
  final Completer<void>? profileCompleter;
  int getTokenCalls = 0;
  int getProfileCalls = 0;
  int logoutCalls = 0;

  @override
  Future<String?> getToken() async {
    getTokenCalls += 1;
    return token;
  }

  @override
  Future<Map<String, dynamic>> getProfile({bool forceRefresh = false}) async {
    getProfileCalls += 1;
    await profileCompleter?.future;
    return profileResponse;
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthProvider', () {
    test('restores a saved session without clearing it on launch', () async {
      final apiService = _FakeApiService(
        token: 'saved-token',
        profileResponse: const {
          'success': true,
          'data': {
            'user': {
              'user_id': 'user-1',
              'email': 'student@example.com',
              'role': 'student',
            },
          },
        },
      );

      final provider = AuthProvider(apiService: apiService);
      await provider.checkAuthStatus();

      expect(apiService.logoutCalls, 0);
      expect(apiService.getProfileCalls, 1);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.user?['email'], 'student@example.com');
    });

    test('coalesces concurrent auth restoration requests', () async {
      final profileCompleter = Completer<void>();
      final apiService = _FakeApiService(
        token: 'saved-token',
        profileCompleter: profileCompleter,
        profileResponse: const {
          'success': true,
          'data': {
            'user': {
              'user_id': 'user-2',
              'email': 'admin@example.com',
              'role': 'admin',
            },
          },
        },
      );

      final provider = AuthProvider(apiService: apiService);
      final firstRestore = provider.checkAuthStatus();
      final secondRestore = provider.checkAuthStatus();
      await Future<void>.delayed(Duration.zero);

      expect(apiService.getTokenCalls, 1);
      expect(apiService.getProfileCalls, 1);

      profileCompleter.complete();
      await Future.wait([firstRestore, secondRestore]);

      expect(provider.isAuthenticated, isTrue);
      expect(provider.user?['role'], 'admin');
    });
  });
}
