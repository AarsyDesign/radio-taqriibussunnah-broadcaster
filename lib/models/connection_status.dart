enum ConnectionStatus {
  offline,
  connecting,
  live,
  reconnecting,
  authenticationFailed,
  serverUnreachable,
  microphoneDenied,
  connectionDropped,
  stopped,
}

extension ConnectionStatusLabel on ConnectionStatus {
  String get label {
    return switch (this) {
      ConnectionStatus.offline => 'Offline',
      ConnectionStatus.connecting => 'Connecting',
      ConnectionStatus.live => 'Live',
      ConnectionStatus.reconnecting => 'Reconnecting',
      ConnectionStatus.authenticationFailed => 'Authentication Failed',
      ConnectionStatus.serverUnreachable => 'Server Unreachable',
      ConnectionStatus.microphoneDenied => 'Microphone Denied',
      ConnectionStatus.connectionDropped => 'Connection Dropped',
      ConnectionStatus.stopped => 'Stopped',
    };
  }

  String get detail {
    return switch (this) {
      ConnectionStatus.offline => 'Belum ada siaran aktif.',
      ConnectionStatus.connecting => 'Menyambungkan ke server radio.',
      ConnectionStatus.live => 'Siaran sedang berjalan.',
      ConnectionStatus.reconnecting => 'Mencoba menyambung ulang.',
      ConnectionStatus.authenticationFailed =>
        'Username atau password ditolak.',
      ConnectionStatus.serverUnreachable => 'Server tidak dapat dijangkau.',
      ConnectionStatus.microphoneDenied => 'Izin mikrofon belum diberikan.',
      ConnectionStatus.connectionDropped => 'Koneksi siaran terputus.',
      ConnectionStatus.stopped => 'Siaran dihentikan operator.',
    };
  }
}
