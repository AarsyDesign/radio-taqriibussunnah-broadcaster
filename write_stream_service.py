import base64

content = b"""
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

enum StreamStatus {
  offline,
  connecting,
  live,
  reconnecting,
  authentication_failed,
  server_unreachable,
  microphone_denied,
  connection_dropped,
  stopped
}

class StreamStats {
  final int durationSec;
  final int totalBytes;
  final double speedKbps;
  final double avgSpeedKbps;
  final String networkType;
  final int reconnectCount;

  StreamStats({
    required this.durationSec,
    required this.totalBytes,
    required this.speedKbps,
    required this.avgSpeedKbps,
    required this.networkType,
    required this.reconnectCount,
  });

  factory StreamStats.empty() {
    return StreamStats(
      durationSec: 0,
      totalBytes: 0,
      speedKbps: 0.0,
      avgSpeedKbps: 0.0,
      networkType: 'Unknown',
      reconnectCount: 0,
    );
  }
}

class StreamService {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.radiotaqriibussunnah.broadcaster/stream',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.radiotaqriibussunnah.broadcaster/events',
  );

  final _secureStorage = const FlutterSecureStorage();

  final _statusController = StreamController<StreamStatus>.broadcast();
  final _logController = StreamController<String>.broadcast();
  final _audioLevelController = StreamController<double>.broadcast();
  final _statsController = StreamController<StreamStats>.broadcast();

  Stream<StreamStatus> get statusStream => _statusController.stream;
  Stream<String> get logStream => _logController.stream;
  Stream<double> get audioLevelStream => _audioLevelController.stream;
  Stream<StreamStats> get statsStream => _statsController.stream;

  StreamStatus _currentStatus = StreamStatus.offline;
  StreamStatus get currentStatus => _currentStatus;

  StreamService() {
    _eventChannel.receiveBroadcastStream().listen(_onEvent, onError: _onError);
  }

  void _onEvent(dynamic event) {
    if (event is Map) {
      final type = event['type'];
      switch (type) {
        case 'status':
          final statusStr = event['value'] as String;
          _currentStatus = StreamStatus.values.firstWhere(
            (e) => e.toString().split('.').last == statusStr,
            orElse: () => StreamStatus.offline,
          );
          _statusController.add(_currentStatus);
          break;
        case 'log':
          _logController.add(event['value'] as String);
          break;
        case 'audioLevel':
          _audioLevelController.add((event['value'] as num).toDouble());
          break;
        case 'stats':
          _statsController.add(StreamStats(
            durationSec: (event['durationSec'] as num).toInt(),
            totalBytes: (event['totalBytes'] as num).toInt(),
            speedKbps: (event['speedKbps'] as num).toDouble(),
            avgSpeedKbps: (event['avgSpeedKbps'] as num).toDouble(),
            networkType: event['networkType'] as String,
            reconnectCount: (event['reconnectCount'] as num).toInt(),
          ));
          break;
      }
    }
  }

  void _onError(Object error) {
    _logController.add("EventChannel Error: " + error.toString());
  }

  Future<void> saveConfig({
    required String host,
    required int port,
    required String mountPoint,
    required String username,
    required String password,
    required int bitrate,
    required int sampleRate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('host', host);
    await prefs.setInt('port', port);
    await prefs.setString('mountPoint', mountPoint);
    await prefs.setString('username', username);
    await prefs.setInt('bitrate', bitrate);
    await prefs.setInt('sampleRate', sampleRate);

    await _secureStorage.write(key: 'dj_password', value: password);
  }

  Future<Map<String, dynamic>> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final password = await _secureStorage.read(key: 'dj_password') ?? '';

    return {
      'host': prefs.getString('host') ?? '',
      'port': prefs.getInt('port') ?? 8000,
      'mountPoint': prefs.getString('mountPoint') ?? '/live',
      'username': prefs.getString('username') ?? 'dj',
      'password': password,
      'bitrate': prefs.getInt('bitrate') ?? 128,
      'sampleRate': prefs.getInt('sampleRate') ?? 44100,
    };
  }

  Future<bool> testConnection() async {
    try {
      final config = await getConfig();
      final result = await _methodChannel.invokeMethod(
        'testConnection',
        config,
      );
      return result as bool;
    } on PlatformException catch (e) {
      _logController.add("Test Connection Failed: " + (e.message ?? ''));
      return false;
    }
  }

  Future<void> startStreaming() async {
    try {
      final config = await getConfig();
      await _methodChannel.invokeMethod('startStream', config);
    } on PlatformException catch (e) {
      _logController.add("Failed to start stream: " + (e.message ?? ''));
      _currentStatus = StreamStatus.server_unreachable;
      _statusController.add(_currentStatus);
    }
  }

  Future<void> stopStreaming() async {
    try {
      await _methodChannel.invokeMethod('stopStream');
    } on PlatformException catch (e) {
      _logController.add("Failed to stop stream: " + (e.message ?? ''));
    }
  }

  void dispose() {
    _statusController.close();
    _logController.close();
    _audioLevelController.close();
    _statsController.close();
  }
}
"""

with open('lib/stream_service.dart', 'wb') as f:
    f.write(content)
