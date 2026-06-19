// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:broadcaster/app.dart';
import 'package:broadcaster/models/broadcast_log.dart';
import 'package:broadcaster/models/broadcaster_config.dart';
import 'package:broadcaster/models/live_metadata.dart';
import 'package:broadcaster/services/broadcast_log_storage_service.dart';
import 'package:broadcaster/services/config_storage_service.dart';
import 'package:broadcaster/services/microphone_permission_service.dart';
import 'package:broadcaster/services/native_broadcast_service.dart';
import 'package:broadcaster/services/network_info_service.dart';
import 'package:broadcaster/providers/broadcaster_provider.dart';
import 'package:broadcaster/models/connection_status.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Broadcaster app shows live controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => BroadcasterProvider(
          configStorageService: _FakeConfigStorageService(),
          logStorageService: _FakeBroadcastLogStorageService(),
          nativeBroadcastService: _FakeNativeBroadcastService(),
          networkInfoService: _FakeNetworkInfoService(),
        ),
        child: const BroadcasterApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Live Broadcast'), findsOneWidget);
    expect(find.text('Kualitas Audio'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Monitoring Internet'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Monitoring Internet'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Nama Ustadz'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Nama Ustadz'), findsOneWidget);
    expect(find.text('Judul Kajian'), findsOneWidget);
    expect(find.text('Tema Pembahasan'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Mulai Siaran'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mulai Siaran'), findsOneWidget);
  });

  test('buildLiveMetadata joins filled fields and falls back when empty', () {
    expect(
      buildLiveMetadata(
        ' Ustadz Abu Zaid ',
        'Kitab\nTauhid',
        ' Bab   Takut Kepada Syirik ',
      ),
      'Ustadz Abu Zaid - Kitab Tauhid - Bab Takut Kepada Syirik',
    );
    expect(buildLiveMetadata('Ustadz Abu Zaid', '', ''), 'Ustadz Abu Zaid');
    expect(
      buildLiveMetadata('', 'Kitab Tauhid', 'Bab Takut Kepada Syirik'),
      'Kitab Tauhid - Bab Takut Kepada Syirik',
    );
    expect(buildLiveMetadata('', '', ''), liveMetadataFallback);
  });

  test('test connection keeps native success and failures distinct', () async {
    for (final failure in [
      ConnectionStatus.authenticationFailed,
      ConnectionStatus.timeout,
      ConnectionStatus.protocolRejected,
    ]) {
      final nativeService = _FakeNativeBroadcastService()
        ..testConnectionStatus = failure;
      final provider = _buildProvider(nativeService: nativeService);
      await _settleProviderStartup();

      await provider.testConnection(_workingIcecastConfig);

      expect(nativeService.testConnectionCalls, 1);
      expect(provider.testResultStatus, failure);
      expect(provider.status, failure);
      expect(provider.isLive, isFalse);
      provider.dispose();
    }

    final nativeService = _FakeNativeBroadcastService()
      ..testConnectionStatus = ConnectionStatus.live;
    final provider = _buildProvider(nativeService: nativeService);
    await _settleProviderStartup();

    await provider.testConnection(_workingIcecastConfig);

    expect(nativeService.testConnectionCalls, 1);
    expect(provider.testResultStatus, ConnectionStatus.live);
    expect(provider.status, ConnectionStatus.offline);
    expect(provider.isLive, isFalse);
    provider.dispose();
  });

  test(
    'start broadcast waits for native live status before showing live',
    () async {
      final nativeService = _FakeNativeBroadcastService();
      final provider = _buildProvider(nativeService: nativeService);
      await _settleProviderStartup();
      await provider.saveConfig(_workingIcecastConfig);

      final result = await provider.startBroadcast(
        ustadzName: 'Ustadz Abu Zaid',
        kajianTitle: 'Kitab Tauhid',
        kajianTheme: 'Bab Takut Kepada Syirik',
      );

      expect(result, StartBroadcastResult.started);
      expect(nativeService.startCalls, 1);
      expect(
        nativeService.lastStartedConfig?.serverType,
        _workingIcecastConfig.serverType,
      );
      expect(nativeService.lastStartedConfig?.host, _workingIcecastConfig.host);
      expect(nativeService.lastStartedConfig?.port, _workingIcecastConfig.port);
      expect(
        nativeService.lastStartedConfig?.mountPoint,
        _workingIcecastConfig.mountPoint,
      );
      expect(
        nativeService.lastStartedConfig?.username,
        _workingIcecastConfig.username,
      );
      expect(
        nativeService.lastStartedConfig?.password,
        _workingIcecastConfig.password,
      );
      expect(
        nativeService.lastLiveMetadata,
        'Ustadz Abu Zaid - Kitab Tauhid - Bab Takut Kepada Syirik',
      );
      expect(provider.status, ConnectionStatus.connecting);
      expect(provider.isLive, isFalse);

      nativeService.emitStatus(ConnectionStatus.live);
      await _settleProviderStartup();

      expect(provider.status, ConnectionStatus.live);
      expect(provider.isLive, isTrue);

      nativeService.emitStats(
        const NativeBroadcastStats(
          totalUploadBytes: 4096,
          uploadSpeedKbps: 64,
          averageUploadKbps: 64,
          reconnectCount: 0,
          reconnectAttempt: 0,
          nextReconnectDelayMs: 0,
          recordingFilePath: '',
          recordingBytes: 0,
        ),
      );
      await _settleProviderStartup();

      expect(provider.totalUploadBytes, 4096);

      await provider.stopBroadcast();

      expect(nativeService.stopCalls, 1);
      expect(provider.status, ConnectionStatus.stopped);
      provider.dispose();
    },
  );
}

const _workingIcecastConfig = BroadcasterConfig(
  host: 'radio.mahadtaqriibussunnah.my.id',
  port: 8005,
  mountPoint: '/',
  username: 'kajian',
  password: 'secret',
  bitrate: 64,
  audioInput: 'Mic HP',
  serverType: BroadcasterConfig.icecast,
  audioPreset: BroadcasterConfig.presetStandarKajian,
  inputGainDb: 0,
  noiseSuppressionLevel: BroadcasterConfig.noiseLow,
  highPassFilterHz: 80,
  limiterEnabled: true,
  audioSourceMode: BroadcasterConfig.audioSourceNatural,
);

BroadcasterProvider _buildProvider({
  required _FakeNativeBroadcastService nativeService,
}) {
  return BroadcasterProvider(
    configStorageService: _FakeConfigStorageService(
      config: _workingIcecastConfig,
    ),
    logStorageService: _FakeBroadcastLogStorageService(),
    microphonePermissionService: _FakeMicrophonePermissionService(),
    nativeBroadcastService: nativeService,
    networkInfoService: _FakeNetworkInfoService(),
  );
}

Future<void> _settleProviderStartup() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeConfigStorageService extends ConfigStorageService {
  _FakeConfigStorageService({BroadcasterConfig? config})
    : _config =
          config ??
          const BroadcasterConfig(
            host: 'radio.test',
            port: 8000,
            mountPoint: '',
            username: 'operator',
            password: 'secret',
            bitrate: 64,
            audioInput: 'Mic HP',
            serverType: BroadcasterConfig.shoutcast,
            audioPreset: BroadcasterConfig.presetStandarKajian,
            inputGainDb: 0,
            noiseSuppressionLevel: BroadcasterConfig.noiseLow,
            highPassFilterHz: 80,
            limiterEnabled: true,
            audioSourceMode: BroadcasterConfig.audioSourceNatural,
          );

  BroadcasterConfig _config;

  @override
  Future<BroadcasterConfig> loadConfig() async {
    return _config;
  }

  @override
  Future<void> saveConfig(BroadcasterConfig config) async {
    _config = config;
  }

  @override
  Future<void> clearConfig() async {
    _config = BroadcasterConfig.empty;
  }
}

class _FakeBroadcastLogStorageService extends BroadcastLogStorageService {
  List<BroadcastLog> savedLogs = [];

  @override
  Future<List<BroadcastLog>> loadLogs() async => [];

  @override
  Future<void> saveLogs(List<BroadcastLog> logs) async {
    savedLogs = logs;
  }

  @override
  Future<void> clearLogs() async {
    savedLogs = [];
  }
}

class _FakeNetworkInfoService extends NetworkInfoService {
  @override
  Future<String> getNetworkType() async => 'WiFi';
}

class _FakeMicrophonePermissionService extends MicrophonePermissionService {
  @override
  Future<MicrophonePermissionResult> requestPermission() async {
    return MicrophonePermissionResult.granted;
  }
}

class _FakeNativeBroadcastService extends NativeBroadcastService {
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _audioLevelController = StreamController<double>.broadcast();
  final _audioDiagnosticController =
      StreamController<AudioDiagnostic>.broadcast();
  final _statsController = StreamController<NativeBroadcastStats>.broadcast();
  final _logController = StreamController<String>.broadcast();

  ConnectionStatus testConnectionStatus = ConnectionStatus.live;
  bool startResult = true;
  int testConnectionCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  BroadcasterConfig? lastTestedConfig;
  BroadcasterConfig? lastStartedConfig;
  String lastLiveMetadata = '';

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  @override
  Stream<double> get audioLevelStream => _audioLevelController.stream;

  @override
  Stream<AudioDiagnostic> get audioDiagnosticStream =>
      _audioDiagnosticController.stream;

  @override
  Stream<NativeBroadcastStats> get statsStream => _statsController.stream;

  @override
  Stream<String> get logStream => _logController.stream;

  @override
  Future<ConnectionStatus?> getServiceStatus() async =>
      ConnectionStatus.offline;

  @override
  Future<ConnectionStatus> testBroadcastConnection(
    BroadcasterConfig config,
  ) async {
    testConnectionCalls += 1;
    lastTestedConfig = config;
    return testConnectionStatus;
  }

  @override
  Future<bool> startBroadcastService({
    required BroadcasterConfig config,
    required String ustadzName,
    required String kajianTitle,
    required String kajianTheme,
    required String liveMetadata,
  }) async {
    startCalls += 1;
    lastStartedConfig = config;
    lastLiveMetadata = liveMetadata;
    return startResult;
  }

  @override
  Future<bool> stopBroadcastService() async {
    stopCalls += 1;
    return true;
  }

  void emitStatus(ConnectionStatus status) {
    _statusController.add(status);
  }

  void emitStats(NativeBroadcastStats stats) {
    _statsController.add(stats);
  }
}
