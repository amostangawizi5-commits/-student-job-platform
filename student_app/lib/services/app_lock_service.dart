import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppLockService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _pinKey = 'app_lock_pin';

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
