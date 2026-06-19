import 'dart:async';

import 'package:flutter/services.dart';

import '../models/broadcaster_config.dart';
import '../models/connection_status.dart';

class NativeBroadcastService {
  NativeBroadcastService({
    MethodChannel? methodChannel,
    EventChannel? statusEventChannel,
    EventChannel? audioLevelEventChannel,
    EventChannel? statsEventChannel,
    EventChannel? logEventChannel,
  }) : _methodChannel =
           methodChannel ??
           const MethodChannel(
             'com.radiotaqriibussunnah.broadcaster/broadcast',
           ),
       _statusEventChannel =
           statusEventChannel ??
           const EventChannel(
             'com.radiotaqriibussunnah.broadcaster/broadcast_events',
           ),
       _audioLevelEventChannel =
           audioLevelEventChannel ??
           const EventChannel(
             'com.radiotaqriibussunnah.broadcaster/audio_level_events',
           ),
       _statsEventChannel =
           statsEventChannel ??
           const EventChannel(
             'com.radiotaqriibussunnah.broadcaster/stats_events',
           ),
       _logEventChannel =
           logEventChannel ??
           const EventChannel(
             'com.radiotaqriibussunnah.broadcaster/log_events',
           );

  final MethodChannel _methodChannel;
  final EventChannel _statusEventChannel;
  final EventChannel _audioLevelEventChannel;
  final EventChannel _statsEventChannel;
  final EventChannel _logEventChannel;

  Stream<ConnectionStatus> get statusStream {
    return _statusEventChannel.receiveBroadcastStream().map((event) {
      return _statusFromNative(event?.toString());
    });
  }

  Stream<double> get audioLevelStream {
    return _audioLevelEventChannel.receiveBroadcastStream().map((event) {
      final level = (event as num?)?.toDouble() ?? 0;
      return level.clamp(0, 1).toDouble();
    });
  }

  Stream<NativeBroadcastStats> get statsStream {
    return _statsEventChannel.receiveBroadcastStream().map((event) {
      final map = Map<Object?, Object?>.from(event as Map<Object?, Object?>);
      return NativeBroadcastStats(
        totalUploadBytes: (map['totalUploadBytes'] as num?)?.toInt() ?? 0,
        uploadSpeedKbps: (map['uploadSpeedKbps'] as num?)?.toDouble() ?? 0,
        averageUploadKbps: (map['averageUploadKbps'] as num?)?.toDouble() ?? 0,
        reconnectCount: (map['reconnectCount'] as num?)?.toInt() ?? 0,
        recordingFilePath: map['recordingFilePath']?.toString() ?? '',
        recordingBytes: (map['recordingBytes'] as num?)?.toInt() ?? 0,
      );
    });
  }

  Stream<String> get logStream {
    return _logEventChannel.receiveBroadcastStream().map((event) {
      return event?.toString() ?? '';
    });
  }

  Future<bool> startBroadcastService({
    required BroadcasterConfig config,
    required String ustadzName,
    required String kajianTitle,
    required String kajianTheme,
    required String liveMetadata,
  }) async {
    try {
      return await _methodChannel.invokeMethod<bool>('startBroadcastService', {
            'host': config.host,
            'port': config.port,
            'mountPoint': config.mountPoint,
            'username': config.username,
            'password': config.password,
            'bitrate': config.bitrate,
            'serverType': config.serverType,
            'ustadzName': ustadzName,
            'kajianTitle': kajianTitle,
            'kajianTheme': kajianTheme,
            'liveMetadata': liveMetadata,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> stopBroadcastService() async {
    try {
      return await _methodChannel.invokeMethod<bool>('stopBroadcastService') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<ConnectionStatus?> getServiceStatus() async {
    try {
      final status = await _methodChannel.invokeMethod<String>(
        'getServiceStatus',
      );
      return _statusFromNative(status);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<ConnectionStatus> testBroadcastConnection(
    BroadcasterConfig config,
  ) async {
    try {
      final status = await _methodChannel
          .invokeMethod<String>('testBroadcastConnection', {
            'host': config.host,
            'port': config.port,
            'mountPoint': config.mountPoint,
            'username': config.username,
            'password': config.password,
            'bitrate': config.bitrate,
            'serverType': config.serverType,
          });
      return _statusFromNative(status);
    } on MissingPluginException {
      return ConnectionStatus.serverUnreachable;
    } on PlatformException {
      return ConnectionStatus.unknownError;
    }
  }

  ConnectionStatus _statusFromNative(String? value) {
    return switch (value) {
      'connecting' => ConnectionStatus.connecting,
      'live' => ConnectionStatus.live,
      'reconnecting' => ConnectionStatus.reconnecting,
      'authenticationFailed' => ConnectionStatus.authenticationFailed,
      'serverUnreachable' => ConnectionStatus.serverUnreachable,
      'connectionDropped' => ConnectionStatus.connectionDropped,
      'timeout' => ConnectionStatus.timeout,
      'invalidConfig' => ConnectionStatus.invalidConfig,
      'protocolRejected' => ConnectionStatus.protocolRejected,
      'unsupportedCodec' => ConnectionStatus.unsupportedCodec,
      'unknownError' => ConnectionStatus.unknownError,
      'stopped' => ConnectionStatus.stopped,
      _ => ConnectionStatus.offline,
    };
  }
}

class NativeBroadcastStats {
  const NativeBroadcastStats({
    required this.totalUploadBytes,
    required this.uploadSpeedKbps,
    required this.averageUploadKbps,
    required this.reconnectCount,
    required this.recordingFilePath,
    required this.recordingBytes,
  });

  final int totalUploadBytes;
  final double uploadSpeedKbps;
  final double averageUploadKbps;
  final int reconnectCount;
  final String recordingFilePath;
  final int recordingBytes;
}
