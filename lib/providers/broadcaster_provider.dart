import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/broadcast_log.dart';
import '../models/broadcaster_config.dart';
import '../models/connection_status.dart';
import '../services/broadcast_log_storage_service.dart';
import '../services/config_storage_service.dart';
import '../services/connection_test_service.dart';
import '../services/microphone_permission_service.dart';
import '../services/native_broadcast_service.dart';
import '../services/network_info_service.dart';

enum StartBroadcastResult {
  started,
  missingConfig,
  microphoneDenied,
  microphonePermanentlyDenied,
}

class BroadcasterProvider extends ChangeNotifier {
  BroadcasterProvider({
    ConfigStorageService? configStorageService,
    BroadcastLogStorageService? logStorageService,
    ConnectionTestService? connectionTestService,
    MicrophonePermissionService? microphonePermissionService,
    NativeBroadcastService? nativeBroadcastService,
    NetworkInfoService? networkInfoService,
  }) : _configStorageService = configStorageService ?? ConfigStorageService(),
       _logStorageService = logStorageService ?? BroadcastLogStorageService(),
       _connectionTestService =
           connectionTestService ?? ConnectionTestService(),
       _microphonePermissionService =
           microphonePermissionService ?? MicrophonePermissionService(),
       _nativeBroadcastService =
           nativeBroadcastService ?? NativeBroadcastService(),
       _networkInfoService = networkInfoService ?? NetworkInfoService() {
    _nativeStatusSubscription = _nativeBroadcastService.statusStream.listen(
      _handleNativeStatus,
      onError: (_) {},
    );
    _nativeAudioLevelSubscription = _nativeBroadcastService.audioLevelStream
        .listen(_handleNativeAudioLevel, onError: (_) {});
    _nativeStatsSubscription = _nativeBroadcastService.statsStream.listen(
      _handleNativeStats,
      onError: (_) {},
    );
    _nativeLogSubscription = _nativeBroadcastService.logStream.listen(
      _handleNativeLog,
      onError: (_) {},
    );
    loadStartupData();
  }

  final ConfigStorageService _configStorageService;
  final BroadcastLogStorageService _logStorageService;
  final ConnectionTestService _connectionTestService;
  final MicrophonePermissionService _microphonePermissionService;
  final NativeBroadcastService _nativeBroadcastService;
  final NetworkInfoService _networkInfoService;
  final _random = Random(12);

  Timer? _timer;
  StreamSubscription<ConnectionStatus>? _nativeStatusSubscription;
  StreamSubscription<double>? _nativeAudioLevelSubscription;
  StreamSubscription<NativeBroadcastStats>? _nativeStatsSubscription;
  StreamSubscription<String>? _nativeLogSubscription;
  DateTime? _startedAt;
  bool _nativeServiceRunning = false;
  bool _usingNativeAudioLevel = false;
  bool _usingNativeStats = false;
  bool _sessionLogSaved = false;
  final List<String> nativeLogMessages = [];

  BroadcasterConfig config = BroadcasterConfig.empty;
  ConnectionStatus status = ConnectionStatus.offline;
  TestConnectionResult testResult = TestConnectionResult.idle;

  bool isLoading = true;
  Duration duration = Duration.zero;
  double audioLevel = 0.18;
  int totalUploadBytes = 0;
  double uploadSpeedKbps = 0;
  double averageUploadKbps = 0;
  String networkType = 'Unknown';
  int reconnectCount = 0;
  List<BroadcastLog> logs = [];

  String get host => config.host;
  String get port => config.port.toString();
  String get mountPoint => config.mountPoint;
  String get djUsername => config.username;
  String get djPassword => config.password;
  int get bitrate => config.bitrate;
  String get audioInput => config.audioInput;
  double get totalUploadMb => totalUploadBytes / 1024 / 1024;

  bool get isLive => status == ConnectionStatus.live;
  bool get isBusy =>
      status == ConnectionStatus.connecting ||
      status == ConnectionStatus.reconnecting;
  bool get hasCompleteConfig => config.isComplete;

  double get estimatedDataPerHourMb => averageUploadKbps <= 0
      ? bitrate * 0.45
      : averageUploadKbps * 1000 / 8 * 3600 / 1024 / 1024;

  Future<void> loadStartupData() async {
    isLoading = true;
    notifyListeners();

    final loadedConfig = await _configStorageService.loadConfig();
    final loadedLogs = await _logStorageService.loadLogs();
    final loadedNetwork = await _networkInfoService.getNetworkType();

    config = loadedConfig;
    logs = loadedLogs;
    networkType = loadedNetwork;
    final nativeStatus = await _nativeBroadcastService.getServiceStatus();
    if (nativeStatus != null && nativeStatus != ConnectionStatus.offline) {
      status = nativeStatus;
      _nativeServiceRunning =
          nativeStatus == ConnectionStatus.connecting ||
          nativeStatus == ConnectionStatus.live ||
          nativeStatus == ConnectionStatus.reconnecting;
      if (nativeStatus == ConnectionStatus.live) {
        _startedAt ??= DateTime.now();
        _startStatsTimer();
      }
    }
    isLoading = false;
    notifyListeners();
  }

  List<String> validateSetupConfig(BroadcasterConfig candidate) {
    final errors = <String>[];
    if (candidate.host.trim().isEmpty) errors.add('Host wajib diisi');
    if (candidate.port < 1 || candidate.port > 65535) {
      errors.add('Port wajib angka');
    }
    if (candidate.mountPoint.trim().isEmpty) {
      errors.add('Mount point wajib diisi');
    }
    if (candidate.username.trim().isEmpty) errors.add('Username wajib diisi');
    if (candidate.password.isEmpty) errors.add('Password wajib diisi');
    return errors;
  }

  Future<void> saveConfig(BroadcasterConfig nextConfig) async {
    final normalizedConfig = nextConfig.copyWith(
      host: nextConfig.host.trim(),
      mountPoint: nextConfig.mountPoint.trim(),
      username: nextConfig.username.trim(),
    );
    config = normalizedConfig;
    await _configStorageService.saveConfig(normalizedConfig);
    notifyListeners();
  }

  Future<void> clearConfig() async {
    config = BroadcasterConfig.empty;
    await _configStorageService.clearConfig();
    notifyListeners();
  }

  Future<void> testConnection(BroadcasterConfig nextConfig) async {
    await saveConfig(nextConfig);
    testResult = TestConnectionResult.idle;
    status = ConnectionStatus.connecting;
    notifyListeners();

    final result = await _connectionTestService.test(config);
    testResult = result;
    status = switch (result) {
      TestConnectionResult.success => ConnectionStatus.offline,
      TestConnectionResult.authenticationFailed =>
        ConnectionStatus.authenticationFailed,
      TestConnectionResult.serverUnreachable =>
        ConnectionStatus.serverUnreachable,
      TestConnectionResult.idle => ConnectionStatus.offline,
    };
    notifyListeners();
  }

  Future<StartBroadcastResult> startBroadcast() async {
    if (isLive || isBusy) return StartBroadcastResult.started;

    if (!hasCompleteConfig) {
      return StartBroadcastResult.missingConfig;
    }

    final micPermission = await _microphonePermissionService
        .requestPermission();
    if (micPermission != MicrophonePermissionResult.granted) {
      status = ConnectionStatus.microphoneDenied;
      notifyListeners();
      return micPermission == MicrophonePermissionResult.permanentlyDenied
          ? StartBroadcastResult.microphonePermanentlyDenied
          : StartBroadcastResult.microphoneDenied;
    }

    networkType = await _networkInfoService.getNetworkType();
    _prepareNewSession();
    notifyListeners();

    final didStartNative = await _nativeBroadcastService.startBroadcastService(
      config: config,
    );
    if (didStartNative) {
      _nativeServiceRunning = true;
      _usingNativeAudioLevel = true;
      return StartBroadcastResult.started;
    }

    await Future<void>.delayed(const Duration(milliseconds: 700));

    status = ConnectionStatus.live;
    _startStatsTimer();
    notifyListeners();
    return StartBroadcastResult.started;
  }

  Future<void> stopBroadcast() async {
    if (!isLive &&
        !isBusy &&
        status != ConnectionStatus.reconnecting &&
        status != ConnectionStatus.connectionDropped) {
      return;
    }

    if (_nativeServiceRunning) {
      await _nativeBroadcastService.stopBroadcastService();
      _nativeServiceRunning = false;
      _usingNativeAudioLevel = false;
    }
    status = ConnectionStatus.stopped;
    audioLevel = 0;
    _timer?.cancel();
    await _saveSessionLog(ConnectionStatus.stopped);
    notifyListeners();
  }

  Future<void> clearLogs() async {
    logs = [];
    await _logStorageService.clearLogs();
    notifyListeners();
  }

  void simulateStatus(ConnectionStatus nextStatus) {
    status = nextStatus;
    if (nextStatus != ConnectionStatus.live &&
        nextStatus != ConnectionStatus.reconnecting &&
        nextStatus != ConnectionStatus.connecting) {
      _timer?.cancel();
    }
    notifyListeners();
  }

  void _prepareNewSession() {
    status = ConnectionStatus.connecting;
    duration = Duration.zero;
    audioLevel = 0.18;
    _usingNativeAudioLevel = false;
    _usingNativeStats = false;
    _sessionLogSaved = false;
    totalUploadBytes = 0;
    uploadSpeedKbps = 0;
    averageUploadKbps = 0;
    reconnectCount = 0;
    _startedAt = DateTime.now();
  }

  void _handleNativeStatus(ConnectionStatus nativeStatus) {
    status = nativeStatus;
    if (nativeStatus == ConnectionStatus.connecting) {
      _nativeServiceRunning = true;
      _usingNativeAudioLevel = true;
      _usingNativeStats = true;
      _startedAt ??= DateTime.now();
    }
    if (nativeStatus == ConnectionStatus.live ||
        nativeStatus == ConnectionStatus.reconnecting) {
      _nativeServiceRunning = true;
      _usingNativeAudioLevel = true;
      _usingNativeStats = true;
      _startedAt ??= DateTime.now();
      _startStatsTimer();
    }
    if (nativeStatus == ConnectionStatus.stopped ||
        nativeStatus == ConnectionStatus.offline ||
        nativeStatus == ConnectionStatus.authenticationFailed ||
        nativeStatus == ConnectionStatus.serverUnreachable) {
      _nativeServiceRunning = false;
      _usingNativeAudioLevel = false;
      _usingNativeStats = false;
      audioLevel = 0;
      _timer?.cancel();
      unawaited(_saveSessionLog(nativeStatus));
    }
    notifyListeners();
  }

  void _handleNativeAudioLevel(double level) {
    if (!_nativeServiceRunning && status != ConnectionStatus.live) return;
    _usingNativeAudioLevel = true;
    audioLevel = level;
    notifyListeners();
  }

  void _handleNativeStats(NativeBroadcastStats stats) {
    _usingNativeStats = true;
    totalUploadBytes = stats.totalUploadBytes;
    uploadSpeedKbps = stats.uploadSpeedKbps;
    averageUploadKbps = stats.averageUploadKbps;
    reconnectCount = stats.reconnectCount;
    notifyListeners();
  }

  void _handleNativeLog(String message) {
    if (message.trim().isEmpty) return;
    nativeLogMessages.insert(0, message);
    if (nativeLogMessages.length > 30) {
      nativeLogMessages.removeRange(30, nativeLogMessages.length);
    }
    notifyListeners();
  }

  void _startStatsTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> refreshNetworkType() async {
    networkType = await _networkInfoService.getNetworkType();
    notifyListeners();
  }

  void _tick() {
    if (status != ConnectionStatus.live &&
        status != ConnectionStatus.reconnecting) {
      return;
    }

    duration += const Duration(seconds: 1);
    if (!_usingNativeAudioLevel) {
      audioLevel = 0.12 + _random.nextDouble() * 0.78;
    }
    if (!_usingNativeStats) {
      uploadSpeedKbps = bitrate + _random.nextDouble() * 28 - 9;
      averageUploadKbps = averageUploadKbps == 0
          ? uploadSpeedKbps
          : (averageUploadKbps * 0.88) + (uploadSpeedKbps * 0.12);
      totalUploadBytes += (uploadSpeedKbps * 1000 / 8).round();
    }

    if (duration.inSeconds % 10 == 0) {
      unawaited(refreshNetworkType());
    }

    if (duration.inSeconds > 0 && duration.inSeconds % 37 == 0) {
      status = ConnectionStatus.reconnecting;
      reconnectCount += 1;
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (status == ConnectionStatus.reconnecting) {
          status = ConnectionStatus.live;
          notifyListeners();
        }
      });
    }

    notifyListeners();
  }

  Future<void> _saveSessionLog(ConnectionStatus finalStatus) async {
    if (_sessionLogSaved || _startedAt == null) return;
    _sessionLogSaved = true;

    final stoppedAt = DateTime.now();
    final log = BroadcastLog(
      id: stoppedAt.microsecondsSinceEpoch.toString(),
      startedAt: _startedAt!,
      stoppedAt: stoppedAt,
      durationSeconds: duration.inSeconds,
      totalUploadBytes: totalUploadBytes,
      reconnectCount: reconnectCount,
      finalStatus: finalStatus,
    );
    logs = [log, ...logs];
    await _logStorageService.saveLogs(logs);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nativeStatusSubscription?.cancel();
    _nativeAudioLevelSubscription?.cancel();
    _nativeStatsSubscription?.cancel();
    _nativeLogSubscription?.cancel();
    super.dispose();
  }
}
