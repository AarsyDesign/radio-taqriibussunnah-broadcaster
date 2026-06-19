import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/broadcast_log.dart';
import '../models/broadcaster_config.dart';
import '../models/connection_status.dart';
import '../models/live_metadata.dart';
import '../services/broadcast_log_storage_service.dart';
import '../services/config_storage_service.dart';
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
    MicrophonePermissionService? microphonePermissionService,
    NativeBroadcastService? nativeBroadcastService,
    NetworkInfoService? networkInfoService,
  }) : _configStorageService = configStorageService ?? ConfigStorageService(),
       _logStorageService = logStorageService ?? BroadcastLogStorageService(),
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
  ConnectionStatus testResultStatus = ConnectionStatus.offline;

  bool isLoading = true;
  Duration duration = Duration.zero;
  double audioLevel = 0.18;
  int totalUploadBytes = 0;
  double uploadSpeedKbps = 0;
  double averageUploadKbps = 0;
  String networkType = 'Unknown';
  int reconnectCount = 0;
  String recordingFilePath = '';
  int recordingBytes = 0;
  String ustadzName = '';
  String kajianTitle = '';
  String kajianTheme = '';
  String liveMetadata = liveMetadataFallback;
  List<BroadcastLog> logs = [];

  String get host => config.host;
  String get port => config.port.toString();
  String get mountPoint => config.mountPoint;
  String get djUsername => config.username;
  String get djPassword => config.password;
  int get bitrate => config.bitrate;
  String get audioInput => config.audioInput;
  String get serverType => config.serverType;
  double get totalUploadMb => totalUploadBytes / 1024 / 1024;
  double get recordingMb => recordingBytes / 1024 / 1024;

  bool get isLive => status == ConnectionStatus.live;
  bool get isBusy =>
      status == ConnectionStatus.connecting ||
      status == ConnectionStatus.reconnecting;
  bool get hasCompleteConfig => config.isComplete;

  double get estimatedDataPerHourMb {
    if (averageUploadKbps > 0) {
      return averageUploadKbps * 1000 / 8 * 3600 / 1024 / 1024;
    }
    return switch (bitrate) {
      32 => 15,
      64 => 30,
      96 => 45,
      128 => 60,
      _ => bitrate * 0.47,
    };
  }

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
    final host = candidate.host.trim();
    final mount = candidate.mountPoint.trim();

    if (host.isEmpty) errors.add('Host wajib diisi');
    if (host.startsWith('http://') || host.startsWith('https://')) {
      errors.add(
        'Ini terlihat seperti URL pendengar. Untuk broadcast, gunakan data source/DJ connection dari AzuraCast.',
      );
    }
    if (candidate.port < 1 || candidate.port > 65535) {
      errors.add('Port wajib angka 1-65535');
    }
    if (!BroadcasterConfig.allowedBitrates.contains(candidate.bitrate)) {
      errors.add('Bitrate wajib 32, 64, 96, atau 128 kbps');
    }
    if (candidate.audioInput.trim().isEmpty) {
      errors.add('Input audio wajib dipilih');
    }
    if (candidate.password.isEmpty) {
      errors.add('Password/source password wajib diisi');
    }

    final looksLikeListenerUrl =
        mount.contains('/listen/') ||
        mount.endsWith('.mp3') ||
        mount.startsWith('http://') ||
        mount.startsWith('https://');
    if (looksLikeListenerUrl) {
      errors.add(
        'Ini terlihat seperti URL pendengar. Untuk broadcast, gunakan data source/DJ connection dari AzuraCast.',
      );
    }

    if (candidate.isShoutcast) {
      if (mount.startsWith('/')) {
        errors.add(
          'SHOUTcast biasanya memakai Stream ID tanpa awalan /. Kosongkan jika SHOUTcast v1 tidak memakai Stream ID.',
        );
      }
    } else {
      if (mount.isEmpty) {
        errors.add('Mount Point Source wajib diisi');
      } else if (!mount.startsWith('/')) {
        errors.add('Mount Point Source harus diawali /');
      }
      if (candidate.username.trim().isEmpty) {
        errors.add('Username DJ wajib diisi');
      }
    }

    _appendValidationLog(
      host: host,
      port: candidate.port,
      mount: mount,
      username: candidate.username.trim(),
      isValid: errors.isEmpty,
    );
    return errors;
  }

  Future<void> saveConfig(BroadcasterConfig nextConfig) async {
    final normalizedConfig = nextConfig.copyWith(
      host: nextConfig.host.trim(),
      mountPoint: nextConfig.mountPoint.trim(),
      username: nextConfig.username.trim(),
      audioInput: nextConfig.audioInput.trim(),
      serverType: nextConfig.serverType,
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
    final errors = validateSetupConfig(nextConfig);
    if (errors.isNotEmpty) {
      testResultStatus = ConnectionStatus.invalidConfig;
      status = ConnectionStatus.invalidConfig;
      _handleNativeLog(errors.first);
      notifyListeners();
      return;
    }

    await saveConfig(nextConfig);
    testResultStatus = ConnectionStatus.connecting;
    status = ConnectionStatus.connecting;
    notifyListeners();

    final resultStatus = await _nativeBroadcastService.testBroadcastConnection(
      config,
    );
    testResultStatus = resultStatus;
    status = resultStatus == ConnectionStatus.live
        ? ConnectionStatus.offline
        : resultStatus;
    notifyListeners();
  }

  Future<StartBroadcastResult> startBroadcast({
    String ustadzName = '',
    String kajianTitle = '',
    String kajianTheme = '',
  }) async {
    if (isLive || isBusy) return StartBroadcastResult.started;

    final errors = validateSetupConfig(config);
    if (errors.isNotEmpty || !hasCompleteConfig) {
      status = ConnectionStatus.invalidConfig;
      if (errors.isNotEmpty) _handleNativeLog(errors.first);
      notifyListeners();
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

    _setSessionMetadata(
      ustadzName: ustadzName,
      kajianTitle: kajianTitle,
      kajianTheme: kajianTheme,
    );
    networkType = await _networkInfoService.getNetworkType();
    _prepareNewSession();
    notifyListeners();

    final didStartNative = await _nativeBroadcastService.startBroadcastService(
      config: config,
      ustadzName: this.ustadzName,
      kajianTitle: this.kajianTitle,
      kajianTheme: this.kajianTheme,
      liveMetadata: liveMetadata,
    );
    if (didStartNative) {
      _nativeServiceRunning = true;
      _usingNativeAudioLevel = true;
      return StartBroadcastResult.started;
    }

    status = ConnectionStatus.serverUnreachable;
    await _saveSessionLog(ConnectionStatus.serverUnreachable);
    notifyListeners();
    return StartBroadcastResult.started;
  }

  Future<void> stopBroadcast() async {
    if (!isLive &&
        !isBusy &&
        status != ConnectionStatus.connectionDropped &&
        status != ConnectionStatus.timeout) {
      return;
    }

    if (_nativeServiceRunning) {
      await _nativeBroadcastService.stopBroadcastService();
      _nativeServiceRunning = false;
      _usingNativeAudioLevel = false;
      _usingNativeStats = false;
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

  void _prepareNewSession() {
    status = ConnectionStatus.connecting;
    testResultStatus = ConnectionStatus.offline;
    duration = Duration.zero;
    audioLevel = 0.18;
    _usingNativeAudioLevel = false;
    _usingNativeStats = false;
    _sessionLogSaved = false;
    totalUploadBytes = 0;
    uploadSpeedKbps = 0;
    averageUploadKbps = 0;
    reconnectCount = 0;
    recordingFilePath = '';
    recordingBytes = 0;
    _startedAt = DateTime.now();
  }

  void _setSessionMetadata({
    required String ustadzName,
    required String kajianTitle,
    required String kajianTheme,
  }) {
    this.ustadzName = cleanLiveMetadataField(ustadzName, maxLength: 80);
    this.kajianTitle = cleanLiveMetadataField(kajianTitle, maxLength: 80);
    this.kajianTheme = cleanLiveMetadataField(kajianTheme, maxLength: 120);
    liveMetadata = buildLiveMetadata(
      this.ustadzName,
      this.kajianTitle,
      this.kajianTheme,
    );
  }

  void _handleNativeStatus(ConnectionStatus nativeStatus) {
    status = nativeStatus;
    if (nativeStatus == ConnectionStatus.connecting) {
      _nativeServiceRunning = true;
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
    if (_isFinalStatus(nativeStatus)) {
      _nativeServiceRunning = false;
      _usingNativeAudioLevel = false;
      _usingNativeStats = false;
      audioLevel = 0;
      _timer?.cancel();
      unawaited(_saveSessionLog(nativeStatus));
    }
    notifyListeners();
  }

  bool _isFinalStatus(ConnectionStatus nextStatus) {
    return nextStatus == ConnectionStatus.stopped ||
        nextStatus == ConnectionStatus.offline ||
        nextStatus == ConnectionStatus.authenticationFailed ||
        nextStatus == ConnectionStatus.serverUnreachable ||
        nextStatus == ConnectionStatus.timeout ||
        nextStatus == ConnectionStatus.invalidConfig ||
        nextStatus == ConnectionStatus.protocolRejected ||
        nextStatus == ConnectionStatus.unsupportedCodec;
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
    recordingFilePath = stats.recordingFilePath;
    recordingBytes = stats.recordingBytes;
    notifyListeners();
  }

  void _handleNativeLog(String message) {
    if (message.trim().isEmpty) return;
    nativeLogMessages.insert(0, '${_formatLogTime(DateTime.now())}\n$message');
    if (nativeLogMessages.length > 40) {
      nativeLogMessages.removeRange(40, nativeLogMessages.length);
    }
    notifyListeners();
  }

  void _appendValidationLog({
    required String host,
    required int port,
    required String mount,
    required String username,
    required bool isValid,
  }) {
    _handleNativeLog(
      '[VALIDATION]\n'
      'host=$host\n'
      'port=$port\n'
      'mount=$mount\n'
      'username=$username\n'
      'result=${isValid ? 'valid' : 'invalid'}',
    );
  }

  String _formatLogTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '[TIME]\n$hour:$minute:$second';
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
      ustadzName: ustadzName,
      kajianTitle: kajianTitle,
      kajianTheme: kajianTheme,
      liveMetadata: liveMetadata,
      recordingFilePath: recordingFilePath,
      recordingBytes: recordingBytes,
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
