class BroadcasterConfig {
  const BroadcasterConfig({
    required this.host,
    required this.port,
    required this.mountPoint,
    required this.username,
    required this.password,
    required this.bitrate,
    required this.audioInput,
    required this.serverType,
    required this.audioPreset,
    required this.inputGainDb,
    required this.noiseSuppressionLevel,
    required this.highPassFilterHz,
    required this.limiterEnabled,
    required this.audioSourceMode,
  });

  static const icecast = 'Icecast/AzuraCast';
  static const shoutcast = 'SHOUTcast';
  static const allowedBitrates = [32, 64, 96, 128];
  static const presetHematData = 'Hemat Data';
  static const presetStandarKajian = 'Standar Kajian';
  static const presetJernih = 'Jernih';
  static const presetMaksimal = 'Maksimal';
  static const noiseOff = 'Off';
  static const noiseLow = 'Low';
  static const noiseMedium = 'Medium';
  static const noiseHigh = 'High';
  static const audioSourceNatural = 'Natural / MIC';
  static const audioSourceVoiceProcessing =
      'Voice Processing / VOICE_COMMUNICATION';

  final String host;
  final int port;
  final String mountPoint;
  final String username;
  final String password;
  final int bitrate;
  final String audioInput;
  final String serverType;
  final String audioPreset;
  final double inputGainDb;
  final String noiseSuppressionLevel;
  final int highPassFilterHz;
  final bool limiterEnabled;
  final String audioSourceMode;

  static const empty = BroadcasterConfig(
    host: '151.245.85.182',
    port: 8005,
    mountPoint: '',
    username: '',
    password: '',
    bitrate: 64,
    audioInput: 'Mic HP',
    serverType: shoutcast,
    audioPreset: presetStandarKajian,
    inputGainDb: 0,
    noiseSuppressionLevel: noiseLow,
    highPassFilterHz: 80,
    limiterEnabled: true,
    audioSourceMode: audioSourceNatural,
  );

  bool get isComplete =>
      host.trim().isNotEmpty &&
      port > 0 &&
      port <= 65535 &&
      allowedBitrates.contains(bitrate) &&
      audioInput.trim().isNotEmpty &&
      (isShoutcast || mountPoint.trim().isNotEmpty) &&
      (isShoutcast || username.trim().isNotEmpty) &&
      password.isNotEmpty;

  bool get isShoutcast => serverType == shoutcast;

  BroadcasterConfig copyWith({
    String? host,
    int? port,
    String? mountPoint,
    String? username,
    String? password,
    int? bitrate,
    String? audioInput,
    String? serverType,
    String? audioPreset,
    double? inputGainDb,
    String? noiseSuppressionLevel,
    int? highPassFilterHz,
    bool? limiterEnabled,
    String? audioSourceMode,
  }) {
    return BroadcasterConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      mountPoint: mountPoint ?? this.mountPoint,
      username: username ?? this.username,
      password: password ?? this.password,
      bitrate: bitrate ?? this.bitrate,
      audioInput: audioInput ?? this.audioInput,
      serverType: serverType ?? this.serverType,
      audioPreset: audioPreset ?? this.audioPreset,
      inputGainDb: inputGainDb ?? this.inputGainDb,
      noiseSuppressionLevel:
          noiseSuppressionLevel ?? this.noiseSuppressionLevel,
      highPassFilterHz: highPassFilterHz ?? this.highPassFilterHz,
      limiterEnabled: limiterEnabled ?? this.limiterEnabled,
      audioSourceMode: audioSourceMode ?? this.audioSourceMode,
    );
  }
}
