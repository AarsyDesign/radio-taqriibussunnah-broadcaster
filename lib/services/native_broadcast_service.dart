import 'dart:async';

import 'package:flutter/services.dart';

import '../models/broadcaster_config.dart';
import '../models/connection_status.dart';

class NativeBroadcastService {
  NativeBroadcastService({
    MethodChannel? methodChannel,
    EventChannel? statusEventChannel,
    EventChannel? audioLevelEventChannel,
    EventChannel? audioDiagnosticEventChannel,
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
       _audioDiagnosticEventChannel =
           audioDiagnosticEventChannel ??
           const EventChannel(
             'com.radiotaqriibussunnah.broadcaster/audio_diagnostic_events',
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
  final EventChannel _audioDiagnosticEventChannel;
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

  Stream<AudioDiagnostic> get audioDiagnosticStream {
    return _audioDiagnosticEventChannel.receiveBroadcastStream().map((event) {
      final map = Map<Object?, Object?>.from(event as Map<Object?, Object?>);
      return AudioDiagnostic(
        rms: (map['rms'] as num?)?.toDouble() ?? 0,
        peak: (map['peak'] as num?)?.toDouble() ?? 0,
        clipping: map['clipping'] == true,
        volumeStatus: map['volumeStatus']?.toString() ?? 'small',
      );
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
        reconnectAttempt: (map['reconnectAttempt'] as num?)?.toInt() ?? 0,
        nextReconnectDelayMs:
            (map['nextReconnectDelayMs'] as num?)?.toInt() ?? 0,
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
            'audioInput': config.audioInput,
            'audioPreset': config.audioPreset,
            'inputGainDb': config.inputGainDb,
            'noiseSuppressionLevel': config.noiseSuppressionLevel,
            'highPassFilterHz': config.highPassFilterHz,
            'limiterEnabled': config.limiterEnabled,
            'audioSourceMode': config.audioSourceMode,
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

  Future<TestRecordingResult?> startTestRecording({
    required BroadcasterConfig config,
  }) async {
    try {
      final result = await _methodChannel
          .invokeMethod<Map<Object?, Object?>>('startTestRecording', {
            'audioInput': config.audioInput,
            'inputGainDb': config.inputGainDb,
            'noiseSuppressionLevel': config.noiseSuppressionLevel,
            'highPassFilterHz': config.highPassFilterHz,
            'limiterEnabled': config.limiterEnabled,
            'audioSourceMode': config.audioSourceMode,
          });
      if (result == null) return null;
      return TestRecordingResult(
        fileName: result['fileName']?.toString() ?? '',
        filePath: result['filePath']?.toString() ?? '',
        sizeBytes: (result['sizeBytes'] as num?)?.toInt() ?? 0,
        durationSeconds: (result['durationSeconds'] as num?)?.toInt() ?? 0,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> playTestRecording(String filePath) async {
    try {
      return await _methodChannel.invokeMethod<bool>('playTestRecording', {
            'filePath': filePath,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> deleteTestRecording(String filePath) async {
    try {
      return await _methodChannel.invokeMethod<bool>('deleteTestRecording', {
            'filePath': filePath,
          }) ??
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
      'networkLost' => ConnectionStatus.networkLost,
      'reconnecting' => ConnectionStatus.reconnecting,
      'liveRestored' => ConnectionStatus.liveRestored,
      'reconnectFailed' => ConnectionStatus.reconnectFailed,
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

class AudioDiagnostic {
  const AudioDiagnostic({
    required this.rms,
    required this.peak,
    required this.clipping,
    required this.volumeStatus,
  });

  final double rms;
  final double peak;
  final bool clipping;
  final String volumeStatus;
}

class NativeBroadcastStats {
  const NativeBroadcastStats({
    required this.totalUploadBytes,
    required this.uploadSpeedKbps,
    required this.averageUploadKbps,
    required this.reconnectCount,
    required this.reconnectAttempt,
    required this.nextReconnectDelayMs,
    required this.recordingFilePath,
    required this.recordingBytes,
  });

  final int totalUploadBytes;
  final double uploadSpeedKbps;
  final double averageUploadKbps;
  final int reconnectCount;
  final int reconnectAttempt;
  final int nextReconnectDelayMs;
  final String recordingFilePath;
  final int recordingBytes;
}

class TestRecordingResult {
  const TestRecordingResult({
    required this.fileName,
    required this.filePath,
    required this.sizeBytes,
    required this.durationSeconds,
  });

  final String fileName;
  final String filePath;
  final int sizeBytes;
  final int durationSeconds;

  double get sizeMb => sizeBytes / 1024 / 1024;
}
