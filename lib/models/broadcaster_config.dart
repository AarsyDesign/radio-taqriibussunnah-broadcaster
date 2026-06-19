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
  });

  static const icecast = 'Icecast/AzuraCast';
  static const shoutcast = 'SHOUTcast';
  static const allowedBitrates = [32, 64, 96, 128];

  final String host;
  final int port;
  final String mountPoint;
  final String username;
  final String password;
  final int bitrate;
  final String audioInput;
  final String serverType;

  static const empty = BroadcasterConfig(
    host: '151.245.85.182',
    port: 8005,
    mountPoint: '',
    username: '',
    password: '',
    bitrate: 64,
    audioInput: 'Mic HP',
    serverType: shoutcast,
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
    );
  }
}
