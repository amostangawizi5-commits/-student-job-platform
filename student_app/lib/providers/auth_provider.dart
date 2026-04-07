// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/app_lock_service.dart';

class AuthProvider extends ChangeNotifier {
  static bool _launchSessionCleared = false;
  final ApiService _apiService = ApiService();

  Map<String, dynamic>? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _sessionRestored = false;
  bool _requiresPinSetup = false;
  String? _errorMessage;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get sessionRestored => _sessionRestored;
  bool get requiresPinSetup => _requiresPinSetup;
  String? get errorMessage => _errorMessage;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  String _normalizeAuthError(Object? error) {
    final message = (error?.toString() ?? '').replaceFirst('Exception: ', '');
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('device is locked') ||
        lowerMessage.contains('app locked') ||
        lowerMessage.contains('app lock') ||
        lowerMessage.contains('locked to another account') ||
        lowerMessage.contains('clear app cache') ||
        lowerMessage.contains('clear cache')) {
      return 'Authentication failed. Please try again.';
    }

    if (lowerMessage.contains('invalid email or password') ||
        lowerMessage.contains('invalid credentials') ||
        lowerMessage.contains('wrong password') ||
        lowerMessage.contains('user not found') ||
        lowerMessage.contains('unauthorized') ||
        lowerMessage.contains('401')) {
      return 'Invalid email or password';
    }

    if (lowerMessage.contains('blocked') ||
        lowerMessage.contains('deactivated') ||
        (lowerMessage.contains('contact') && lowerMessage.contains('support'))) {
      return 'User blocked. Please contact IT support.';
    }

    if (lowerMessage.contains('network') ||
        lowerMessage.contains('timeout') ||
        lowerMessage.contains('cannot connect') ||
        lowerMessage.contains('socket') ||
        lowerMessage.contains('connection refused') ||
        lowerMessage.contains('connection error') ||
        lowerMessage.contains('server not responding')) {
      return 'Network error';
    }

    return 'Login failed';
  }

  // Check if user is logged in on app start
  Future<void> checkAuthStatus() async {
    if (!_launchSessionCleared) {
      _launchSessionCleared = true;
      await _apiService.logout();
      _isAuthenticated = false;
      _sessionRestored = false;
      _requiresPinSetup = false;
      _user = null;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    final token = await _apiService.getToken();
    _log('checkAuthStatus - Token exists: ${token != null}');

    if (token != null && token.isNotEmpty) {
      _sessionRestored = true;
      _requiresPinSetup = false;
      await loadProfile();
      if (!_isAuthenticated) {
        _sessionRestored = false;
      }
    } else {
      _isAuthenticated = false;
      _sessionRestored = false;
      _requiresPinSetup = false;
      _user = null;
      notifyListeners();
    }
  }

  // Register user
  Future<bool> register(Map<String, dynamic> userData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.register(userData);

      if (response['success'] == true) {
        // Extract user data from response
        final userDataMap = response['data']['data']['user'];
        await AppLockService.forUser(userDataMap).clearPin();
        _user = userDataMap;
        _isAuthenticated = true;
        _sessionRestored = true;
        _requiresPinSetup = true;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      }
      _errorMessage = _normalizeAuthError(
        response['message']?.toString() ?? 'Registration failed',
      );
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _log('Register error: $e');
      _errorMessage = _normalizeAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.login(email, password);

      if (response['success'] == true) {
        // Extract user data from the correct path
        // Response structure: {success: true, data: {data: {user: {...}, token: ...}}}
        final responseData = response['data'];
        final userDataMap = responseData['data']['user'];

        _user = userDataMap;
        _isAuthenticated = true;
        _sessionRestored = true;
        _requiresPinSetup = false;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = _normalizeAuthError(response['message']);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _log('Login error: $e');
      _errorMessage = _normalizeAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load profile from token
  Future<void> loadProfile() async {
    try {
      final response = await _apiService.getProfile();

      if (response['success'] == true) {
        final data = response['data'];
        final userDataMap = data is Map<String, dynamic>
            ? (data['user'] is Map<String, dynamic> ? data['user'] : data)
            : null;

        if (userDataMap == null) {
          throw Exception('Invalid profile response format');
        }
        _user = userDataMap;
        _isAuthenticated = true;
        _requiresPinSetup = false;
        notifyListeners();
      } else {
        await logout();
      }
    } catch (e) {
      _log('Load profile error: $e');
      await logout();
    }
  }

  // Logout
  Future<void> logout() async {
    await _apiService.logout();
    _user = null;
    _isAuthenticated = false;
    _sessionRestored = false;
    _requiresPinSetup = false;
    notifyListeners();
  }

  void markSessionUnlocked() {
    _sessionRestored = false;
    _requiresPinSetup = false;
  }

  // Update profile
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.updateProfile(data);
      if (response['success'] == true) {
        if (_user != null) {
          // Update user data
          final responseData = response['data'];
          final updatedUser = responseData is Map<String, dynamic>
              ? (responseData['user'] is Map<String, dynamic>
                    ? responseData['user']
                    : responseData)
              : null;
          if (updatedUser == null) return false;
          _user = updatedUser;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _log('Error updating profile: $e');
      return false;
    }
  }

  // Get user role
  String get userRole => _user?['role'] ?? '';

  // Check if user is student
  bool get isStudent =>
      _user?['role'] == 'student' || _user?['role'] == 'graduate';

  // Check if user is company
  bool get isCompany => _user?['role'] == 'company';

  // Check if user is admin
  bool get isAdmin => _user?['role'] == 'admin';
}
