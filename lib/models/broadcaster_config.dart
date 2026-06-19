class BroadcasterConfig {
  const BroadcasterConfig({
    required this.host,
    required this.port,
    required this.mountPoint,
    required this.username,
    required this.password,
    required this.bitrate,
    required this.audioInput,
  });

  final String host;
  final int port;
  final String mountPoint;
  final String username;
  final String password;
  final int bitrate;
  final String audioInput;

  static const empty = BroadcasterConfig(
    host: '151.245.85.182',
    port: 8005,
    mountPoint: '/listen/radio/radio.mp3',
    username: '',
    password: '',
    bitrate: 96,
    audioInput: 'Mic HP',
  );

  bool get isComplete =>
      host.trim().isNotEmpty &&
      port > 0 &&
      mountPoint.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      password.isNotEmpty;

  BroadcasterConfig copyWith({
    String? host,
    int? port,
    String? mountPoint,
    String? username,
    String? password,
    int? bitrate,
    String? audioInput,
  }) {
    return BroadcasterConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      mountPoint: mountPoint ?? this.mountPoint,
      username: username ?? this.username,
      password: password ?? this.password,
      bitrate: bitrate ?? this.bitrate,
      audioInput: audioInput ?? this.audioInput,
    );
  }
}
