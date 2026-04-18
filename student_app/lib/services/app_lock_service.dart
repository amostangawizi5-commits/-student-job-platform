import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/user_role.dart';

String? buildAppLockAccountScope(Map<String, dynamic>? user) {
  if (user == null) return null;

  final rawUserId = '${user['user_id'] ?? user['id'] ?? ''}'.trim();
  final rawEmail = '${user['email'] ?? ''}'.trim().toLowerCase();
  final rawRole = normalizeUserRole(user['role']);

  final identifier = rawUserId.isNotEmpty ? rawUserId : rawEmail;
  if (identifier.isEmpty) {
    return null;
  }

  return rawRole.isEmpty ? identifier : '$rawRole:$identifier';
}

String buildAppLockPinStorageKey(String? accountScope) {
  const legacyPinKey = 'app_lock_pin';
  const scopedPinKeyPrefix = 'app_lock_pin_v2';

  final normalizedScope = accountScope?.trim().toLowerCase();
  if (normalizedScope == null || normalizedScope.isEmpty) {
    return legacyPinKey;
  }

  return '${scopedPinKeyPrefix}_$normalizedScope';
}

class AppLockService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  final String? _accountScope;

  AppLockService({String? accountScope}) : _accountScope = accountScope;

  factory AppLockService.forUser(Map<String, dynamic>? user) {
    return AppLockService(accountScope: buildAppLockAccountScope(user));
  }

  String get _pinKey => buildAppLockPinStorageKey(_accountScope);

  Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<void> savePin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  Future<bool> verifyPin(String pin) async {
    final savedPin = await _storage.read(key: _pinKey);
    return savedPin != null && savedPin == pin;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinKey);
  }
}
