enum ConnectionStatus {
  offline,
  connecting,
  live,
  networkLost,
  reconnecting,
  liveRestored,
  reconnectFailed,
  authenticationFailed,
  serverUnreachable,
  microphoneDenied,
  connectionDropped,
  timeout,
  invalidConfig,
  protocolRejected,
  unsupportedCodec,
  unknownError,
  stopped,
}

extension ConnectionStatusLabel on ConnectionStatus {
  String get label {
    return switch (this) {
      ConnectionStatus.offline => 'Offline',
      ConnectionStatus.connecting => 'Connecting',
      ConnectionStatus.live => 'Live',
      ConnectionStatus.networkLost => 'Network Lost',
      ConnectionStatus.reconnecting => 'Reconnecting',
      ConnectionStatus.liveRestored => 'Live Restored',
      ConnectionStatus.reconnectFailed => 'Reconnect Failed',
      ConnectionStatus.authenticationFailed => 'Authentication Failed',
      ConnectionStatus.serverUnreachable => 'Server Unreachable',
      ConnectionStatus.microphoneDenied => 'Microphone Denied',
      ConnectionStatus.connectionDropped => 'Connection Dropped',
      ConnectionStatus.timeout => 'Connection Timeout',
      ConnectionStatus.invalidConfig => 'Invalid Configuration',
      ConnectionStatus.protocolRejected => 'Protocol Rejected',
      ConnectionStatus.unsupportedCodec => 'Unsupported Audio Format',
      ConnectionStatus.unknownError => 'Unknown Error',
      ConnectionStatus.stopped => 'Stopped',
    };
  }

  String get detail {
    return switch (this) {
      ConnectionStatus.offline => 'Belum ada siaran aktif.',
      ConnectionStatus.connecting => 'Menyambungkan ke server radio.',
      ConnectionStatus.live => 'Siaran sedang berjalan.',
      ConnectionStatus.networkLost =>
        'Jaringan terputus. Menunggu koneksi kembali.',
      ConnectionStatus.reconnecting =>
        'Koneksi terputus. Mencoba menyambung ulang...',
      ConnectionStatus.liveRestored => 'Siaran tersambung kembali.',
      ConnectionStatus.reconnectFailed =>
        'Gagal menyambung ulang setelah beberapa percobaan.',
      ConnectionStatus.authenticationFailed =>
        'Username atau password ditolak.',
      ConnectionStatus.serverUnreachable => 'Server tidak dapat dijangkau.',
      ConnectionStatus.microphoneDenied => 'Izin mikrofon belum diberikan.',
      ConnectionStatus.connectionDropped =>
        'Koneksi terputus. Mencoba menyambung ulang.',
      ConnectionStatus.timeout =>
        'Koneksi timeout. Cek internet, host, port, atau firewall.',
      ConnectionStatus.invalidConfig => 'Konfigurasi belum benar.',
      ConnectionStatus.protocolRejected =>
        'Server menolak protokol. Coba ganti tipe server (Icecast/SHOUTcast).',
      ConnectionStatus.unsupportedCodec =>
        'Server kemungkinan tidak menerima format audio AAC dari aplikasi ini.',
      ConnectionStatus.unknownError =>
        'Terjadi error tidak dikenal. Cek log native.',
      ConnectionStatus.stopped => 'Siaran dihentikan operator.',
    };
  }
}
