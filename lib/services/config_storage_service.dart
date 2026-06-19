import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/broadcaster_config.dart';

class ConfigStorageService {
  ConfigStorageService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _hostKey = 'config_host';
  static const _portKey = 'config_port';
  static const _mountPointKey = 'config_mount_point';
  static const _usernameKey = 'config_username';
  static const _bitrateKey = 'config_bitrate';
  static const _audioInputKey = 'config_audio_input';
  static const _serverTypeKey = 'config_server_type';
  static const _passwordKey = 'config_password';

  final FlutterSecureStorage _secureStorage;

  Future<void> saveConfig(BroadcasterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, config.host);
    await prefs.setInt(_portKey, config.port);
    await prefs.setString(_mountPointKey, config.mountPoint);
    await prefs.setString(_usernameKey, config.username);
    await prefs.setInt(_bitrateKey, config.bitrate);
    await prefs.setString(_audioInputKey, config.audioInput);
    await prefs.setString(_serverTypeKey, config.serverType);

    await _writePassword(config.password);
  }

  Future<BroadcasterConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final password = await _readPassword();

    return BroadcasterConfig(
      host: prefs.getString(_hostKey) ?? BroadcasterConfig.empty.host,
      port: prefs.getInt(_portKey) ?? BroadcasterConfig.empty.port,
      mountPoint:
          prefs.getString(_mountPointKey) ?? BroadcasterConfig.empty.mountPoint,
      username:
          prefs.getString(_usernameKey) ?? BroadcasterConfig.empty.username,
      password: password,
      bitrate: prefs.getInt(_bitrateKey) ?? BroadcasterConfig.empty.bitrate,
      audioInput:
          prefs.getString(_audioInputKey) ?? BroadcasterConfig.empty.audioInput,
      serverType:
          prefs.getString(_serverTypeKey) ?? BroadcasterConfig.empty.serverType,
    );
  }

  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hostKey);
    await prefs.remove(_portKey);
    await prefs.remove(_mountPointKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_bitrateKey);
    await prefs.remove(_audioInputKey);
    await prefs.remove(_serverTypeKey);
    await _deletePassword();
  }

  Future<String> _readPassword() async {
    try {
      return await _secureStorage.read(key: _passwordKey) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _writePassword(String password) async {
    try {
      await _secureStorage.write(key: _passwordKey, value: password);
    } catch (_) {
      // Secure storage can be unavailable in widget tests.
    }
  }

  Future<void> _deletePassword() async {
    try {
      await _secureStorage.delete(key: _passwordKey);
    } catch (_) {
      // Secure storage can be unavailable in widget tests.
    }
  }
}
