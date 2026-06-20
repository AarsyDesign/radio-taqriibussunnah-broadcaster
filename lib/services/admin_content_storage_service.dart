
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/admin_content.dart';

class AdminContentStorageService {
  static const _contentKey = 'admin_content_v1';
  static const _pinKey = 'admin_pin_v1';
  static const _secureStorage = FlutterSecureStorage();

  Future<AdminContent> loadContent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contentKey);
    if (raw == null || raw.isEmpty) return const AdminContent();
    try {
      return AdminContent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AdminContent();
    }
  }

  Future<void> saveContent(AdminContent content) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contentKey, jsonEncode(content.toJson()));
  }

  Future<bool> hasAdminPin() async {
    final pin = await _secureStorage.read(key: _pinKey);
    return pin != null && pin.length == 6;
  }

  Future<void> saveAdminPin(String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('PIN admin harus 6 digit.');
    }
    await _secureStorage.write(key: _pinKey, value: pin);
  }

  Future<bool> verifyAdminPin(String pin) async {
    final storedPin = await _secureStorage.read(key: _pinKey);
    return storedPin != null && storedPin == pin;
  }
}
