import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/broadcaster_config.dart';
import '../models/connection_status.dart';
import '../providers/broadcaster_provider.dart';
import '../theme/app_theme.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _mountController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  int _bitrate = 64;
  String _audioInput = 'Mic HP';
  String _serverType = BroadcasterConfig.shoutcast;
  bool _obscurePassword = true;
  bool _didApplyStoredConfig = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<BroadcasterProvider>();
    _hostController = TextEditingController(text: provider.host);
    _portController = TextEditingController(text: provider.port);
    _mountController = TextEditingController(text: provider.mountPoint);
    _usernameController = TextEditingController(text: provider.djUsername);
    _passwordController = TextEditingController(text: provider.djPassword);
    _bitrate = provider.bitrate;
    _audioInput = provider.audioInput;
    _serverType = provider.serverType;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BroadcasterProvider>();
    _applyStoredConfigIfNeeded(provider);

    return Scaffold(
      appBar: AppBar(title: const Text('Setup Broadcast')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Radio Taqriibussunnah Broadcaster',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'Konfigurasi server dan input audio operator.',
            style: TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _serverType,
                  decoration: const InputDecoration(
                    labelText: 'Tipe Server',
                    prefixIcon: Icon(Icons.settings_input_antenna_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: BroadcasterConfig.shoutcast,
                      child: Text(BroadcasterConfig.shoutcast),
                    ),
                    DropdownMenuItem(
                      value: BroadcasterConfig.icecast,
                      child: Text(BroadcasterConfig.icecast),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _serverType = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host / Server',
                    prefixIcon: Icon(Icons.dns_rounded),
                  ),
                  validator: (value) => _required(value, 'Host wajib diisi'),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          prefixIcon: Icon(Icons.settings_ethernet_rounded),
                        ),
                        validator: _portValidator,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _mountController,
                        decoration: InputDecoration(
                          labelText: _isShoutcast
                              ? 'Stream ID / Mount'
                              : 'Mount Point Source',
                          helperText: _isShoutcast
                              ? 'Kosongkan jika SHOUTcast v1 tidak memakai stream ID.'
                              : 'Ambil dari Connection Information DJ AzuraCast, bukan URL pendengar.',
                          prefixIcon: const Icon(Icons.link_rounded),
                        ),
                        validator: (value) {
                          if (_isShoutcast) return null;
                          return _required(value, 'Mount point wajib diisi');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: _isShoutcast
                        ? 'Username DJ (opsional)'
                        : 'Username DJ',
                    prefixIcon: const Icon(Icons.person_rounded),
                  ),
                  validator: (value) {
                    if (_isShoutcast) return null;
                    return _required(value, 'Username wajib diisi');
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: _isShoutcast ? 'Source Password' : 'Password DJ',
                    prefixIcon: const Icon(Icons.lock_rounded),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Tampilkan password'
                          : 'Sembunyikan password',
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  ),
                  validator: (value) =>
                      _required(value, 'Password wajib diisi'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _bitrate,
                  decoration: const InputDecoration(
                    labelText: 'Bitrate',
                    prefixIcon: Icon(Icons.speed_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 32,
                      child: Text('32 kbps (Hemat Data)'),
                    ),
                    DropdownMenuItem(
                      value: 64,
                      child: Text('64 kbps (Rekomendasi)'),
                    ),
                    DropdownMenuItem(value: 96, child: Text('96 kbps')),
                    DropdownMenuItem(value: 128, child: Text('128 kbps')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _bitrate = value);
                  },
                ),
                if (_bitrate == 32) ...[
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Mode hemat data. Kualitas suara lebih rendah, tetapi lebih ringan untuk internet lemah.',
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _audioInput,
                  decoration: const InputDecoration(
                    labelText: 'Input Audio',
                    prefixIcon: Icon(Icons.mic_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Mic HP', child: Text('Mic HP')),
                    DropdownMenuItem(
                      value: 'USB Audio Interface',
                      child: Text('USB Audio Interface'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _audioInput = value);
                  },
                ),
                const SizedBox(height: 18),
                _TestResultBanner(result: provider.testResultStatus),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: provider.isBusy ? null : _testConnection,
                  icon: provider.isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded),
                  label: const Text('Tes Koneksi'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saveSetup,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Simpan'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _applyStoredConfigIfNeeded(BroadcasterProvider provider) {
    if (provider.isLoading || _didApplyStoredConfig) return;

    _didApplyStoredConfig = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _hostController.text = provider.host;
        _portController.text = provider.port;
        _mountController.text = provider.mountPoint;
        _usernameController.text = provider.djUsername;
        _passwordController.text = provider.djPassword;
        _bitrate = provider.bitrate;
        _audioInput = provider.audioInput;
        _serverType = provider.serverType;
      });
    });
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<BroadcasterProvider>().testConnection(_buildConfig());
  }

  Future<void> _saveSetup() async {
    if (!_formKey.currentState!.validate()) return;

    await context.read<BroadcasterProvider>().saveConfig(_buildConfig());
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Konfigurasi disimpan permanen')),
    );
  }

  BroadcasterConfig _buildConfig() {
    return BroadcasterConfig(
      host: _hostController.text,
      port: int.tryParse(_portController.text.trim()) ?? -1,
      mountPoint: _mountController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      bitrate: _bitrate,
      audioInput: _audioInput,
      serverType: _serverType,
    );
  }

  bool get _isShoutcast => _serverType == BroadcasterConfig.shoutcast;

  String? _required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _portValidator(String? value) {
    final port = int.tryParse(value ?? '');
    if (port == null) return 'Port wajib angka';
    if (port < 1 || port > 65535) return 'Port wajib angka';
    return null;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _mountController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class _TestResultBanner extends StatelessWidget {
  const _TestResultBanner({required this.result});

  final ConnectionStatus result;

  @override
  Widget build(BuildContext context) {
    if (result == ConnectionStatus.offline) {
      return const SizedBox.shrink();
    }

    final (icon, title, detail, color) = switch (result) {
      ConnectionStatus.live => (
        Icons.check_circle_rounded,
        'Success',
        'Server merespons dan kredensial diterima.',
        AppTheme.leaf,
      ),
      ConnectionStatus.connecting => (
        Icons.sync_rounded,
        'Testing',
        'Menguji koneksi native ke server.',
        AppTheme.amber,
      ),
      ConnectionStatus.authenticationFailed => (
        Icons.lock_person_rounded,
        'Authentication failed',
        'Password/source password salah atau akun DJ tidak diterima.',
        AppTheme.danger,
      ),
      ConnectionStatus.serverUnreachable => (
        Icons.cloud_off_rounded,
        'Server unreachable',
        'Server atau port tidak bisa dijangkau.',
        AppTheme.danger,
      ),
      ConnectionStatus.timeout => (
        Icons.timer_off_rounded,
        'Timeout',
        'Koneksi timeout. Cek internet, host, port, atau firewall.',
        AppTheme.danger,
      ),
      ConnectionStatus.invalidConfig => (
        Icons.rule_folder_rounded,
        'Invalid config',
        'Konfigurasi belum benar.',
        AppTheme.danger,
      ),
      ConnectionStatus.protocolRejected => (
        Icons.sync_problem_rounded,
        'Protocol rejected',
        'Server menolak protocol yang dipilih.',
        AppTheme.danger,
      ),
      ConnectionStatus.unsupportedCodec => (
        Icons.volume_off_rounded,
        'Unsupported codec',
        'Server kemungkinan tidak menerima format audio aplikasi.',
        AppTheme.danger,
      ),
      ConnectionStatus.unknownError => (
        Icons.error_outline_rounded,
        'Unknown error',
        'Terjadi error tidak dikenal. Cek log native.',
        AppTheme.danger,
      ),
      _ => (Icons.info_rounded, result.label, result.detail, AppTheme.muted),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
