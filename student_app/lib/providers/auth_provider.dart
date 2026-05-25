import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../utils/user_role.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Map<String, dynamic>? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _errorMessage;
  Future<void>? _sessionRestoreFuture;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  Map<String, dynamic> _mergeUserData(
    Map<String, dynamic>? fallback,
    Map<String, dynamic> primary,
  ) {
    final merged = <String, dynamic>{
      if (fallback != null) ...fallback,
      ...primary,
    };

    for (final nestedKey in const [
      'student_data',
      'company_data',
      'university_data',
    ]) {
      final fallbackNested = fallback?[nestedKey];
      final primaryNested = primary[nestedKey];
      if (fallbackNested is Map<String, dynamic> ||
          primaryNested is Map<String, dynamic>) {
        merged[nestedKey] = {
          ...?(fallbackNested is Map<String, dynamic> ? fallbackNested : null),
          ...?(primaryNested is Map<String, dynamic> ? primaryNested : null),
        };
      }
    }

    return merged;
  }

  String _normalizeAuthError(Object? error) {
    final message = (error?.toString() ?? '').replaceFirst('Exception: ', '');
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('server is waking up') ||
        lowerMessage.contains('wait 30-60 seconds')) {
      return 'The server is waking up. Please wait 30-60 seconds and try again.';
    }

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
        (lowerMessage.contains('contact') &&
            lowerMessage.contains('support'))) {
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

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _applyAuthState({
    Map<String, dynamic>? user,
    required bool isAuthenticated,
    String? errorMessage,
    bool notify = true,
  }) {
    _user = user;
    _isAuthenticated = isAuthenticated;
    _errorMessage = errorMessage;

    if (notify) {
      notifyListeners();
    }
  }

  Map<String, dynamic>? _extractUserFromAuthResponse(
    Map<String, dynamic> response,
  ) {
    final responseData = response['data'];
    if (responseData is Map<String, dynamic>) {
      final nestedData = responseData['data'];
      if (nestedData is Map<String, dynamic> &&
          nestedData['user'] is Map<String, dynamic>) {
        return nestedData['user'] as Map<String, dynamic>;
      }

      if (responseData['user'] is Map<String, dynamic>) {
        return responseData['user'] as Map<String, dynamic>;
      }
    }

    return null;
  }

  Future<void> _restoreSession() async {
    final token = await _apiService.getToken();
    _log(
      'checkAuthStatus - Token exists: ${token != null && token.isNotEmpty}',
    );

    if (token == null || token.isEmpty) {
      _applyAuthState(user: null, isAuthenticated: false, errorMessage: null);
      return;
    }

    await loadProfile(forceRefresh: true);
  }

  Future<void> checkAuthStatus() async {
    final inFlightRestore = _sessionRestoreFuture;
    if (inFlightRestore != null) {
      await inFlightRestore;
      return;
    }

    final restoreFuture = _restoreSession();
    _sessionRestoreFuture = restoreFuture;

    try {
      await restoreFuture;
    } finally {
      if (identical(_sessionRestoreFuture, restoreFuture)) {
        _sessionRestoreFuture = null;
      }
    }
  }

  Future<bool> register(
    Map<String, dynamic> userData, {
    String? identificationCardFilePath,
    Uint8List? identificationCardFileBytes,
    String? identificationCardFileName,
    String? collegeLogoFilePath,
    Uint8List? collegeLogoFileBytes,
    String? collegeLogoFileName,
  }) async {
    _errorMessage = null;
    _setLoading(true);

    try {
      final response = await _apiService.register(
        userData,
        identificationCardFilePath: identificationCardFilePath,
        identificationCardFileBytes: identificationCardFileBytes,
        identificationCardFileName: identificationCardFileName,
        collegeLogoFilePath: collegeLogoFilePath,
        collegeLogoFileBytes: collegeLogoFileBytes,
        collegeLogoFileName: collegeLogoFileName,
      );

      _log('Register response: $response');

      if (response['success'] == true) {
        _applyAuthState(
          user: _extractUserFromAuthResponse(response),
          isAuthenticated: true,
          errorMessage: null,
        );
        _setLoading(false);
        return true;
      }

      final errorMsg = response['message']?.toString() ?? 'Registration failed';
      _errorMessage = ApiService.sanitizeUserMessage(
        errorMsg,
        fallback: 'Registration failed',
      );
      _log(
        'Register failed - Raw message: $errorMsg, Sanitized: $_errorMessage',
      );
      _setLoading(false);
      notifyListeners();
      return false;
    } catch (e) {
      _log('Register exception: $e');
      _errorMessage = ApiService.normalizeErrorMessage(
        e,
        fallback: 'Registration failed',
      );
      _log('Register exception normalized to: $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _errorMessage = null;
    _setLoading(true);

    try {
      final response = await _apiService.login(email.trim(), password);
      _log('Login response: $response');

      if (response['success'] == true) {
        final user = _extractUserFromAuthResponse(response);
        if (user != null) {
          _applyAuthState(
            user: _mergeUserData(_user, user),
            isAuthenticated: true,
            errorMessage: null,
          );
        } else {
          await loadProfile(forceRefresh: true);
        }
        _setLoading(false);
        return true;
      }

      // Handle error response - extract message properly
      final errorMsg = response['message']?.toString() ?? 'Login failed';
      _log('Login error message: $errorMsg');
      _errorMessage = _normalizeAuthError(errorMsg);
      _log('Normalized error message: $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return false;
    } catch (e) {
      _log('Login exception: $e');
      _errorMessage = _normalizeAuthError(e);
      _log('Exception normalized to: $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<void> loadProfile({bool forceRefresh = false}) async {
    try {
      final response = await _apiService.getProfile(forceRefresh: forceRefresh);

      if (response['success'] == true) {
        final data = response['data'];
        final userDataMap = data is Map<String, dynamic>
            ? (data['user'] is Map<String, dynamic> ? data['user'] : data)
            : null;

        if (userDataMap == null) {
          throw Exception('Invalid profile response format');
        }
        _applyAuthState(
          user: _mergeUserData(_user, userDataMap),
          isAuthenticated: true,
          errorMessage: null,
        );
      } else {
        await logout();
      }
    } catch (e) {
      _log('Load profile error: $e');
      await logout();
    }
  }

  Future<void> logout() async {
    await _apiService.logout();
    _applyAuthState(user: null, isAuthenticated: false, errorMessage: null);
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.updateProfile(data);
      if (response['success'] == true) {
        if (_user != null) {
          final responseData = response['data'];
          final updatedUser = responseData is Map<String, dynamic>
              ? (responseData['user'] is Map<String, dynamic>
                    ? responseData['user']
                    : responseData)
              : null;
          if (updatedUser == null) return false;
          _user = _mergeUserData(_user, updatedUser);
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

  String get userRole => normalizeUserRole(_user?['role']);
  bool get isStudent => isStudentRole(_user?['role']);
  bool get isCompany => isCompanyRole(_user?['role']);
  bool get isUniversity => isUniversityRole(_user?['role']);
  bool get isAdmin => isAdminRole(_user?['role']);
}
