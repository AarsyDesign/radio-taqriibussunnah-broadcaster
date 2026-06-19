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
  String _audioPreset = BroadcasterConfig.presetStandarKajian;
  double _inputGainDb = 0;
  String _noiseSuppressionLevel = BroadcasterConfig.noiseLow;
  int _highPassFilterHz = 80;
  bool _limiterEnabled = true;
  String _audioSourceMode = BroadcasterConfig.audioSourceNatural;
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
    _audioPreset = provider.config.audioPreset;
    _inputGainDb = provider.config.inputGainDb;
    _noiseSuppressionLevel = provider.config.noiseSuppressionLevel;
    _highPassFilterHz = provider.config.highPassFilterHz;
    _limiterEnabled = provider.config.limiterEnabled;
    _audioSourceMode = provider.config.audioSourceMode;
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
                _AudioQualitySection(
                  audioPreset: _audioPreset,
                  inputGainDb: _inputGainDb,
                  noiseSuppressionLevel: _noiseSuppressionLevel,
                  highPassFilterHz: _highPassFilterHz,
                  limiterEnabled: _limiterEnabled,
                  audioSourceMode: _audioSourceMode,
                  onPresetChanged: _applyAudioPreset,
                  onGainChanged: (value) {
                    setState(() => _inputGainDb = value);
                  },
                  onNoiseChanged: (value) {
                    if (value != null) {
                      setState(() => _noiseSuppressionLevel = value);
                    }
                  },
                  onHighPassChanged: (value) {
                    if (value != null) {
                      setState(() => _highPassFilterHz = value);
                    }
                  },
                  onLimiterChanged: (value) {
                    setState(() => _limiterEnabled = value);
                  },
                  onAudioSourceModeChanged: (value) {
                    if (value != null) {
                      setState(() => _audioSourceMode = value);
                    }
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
        _audioPreset = provider.config.audioPreset;
        _inputGainDb = provider.config.inputGainDb;
        _noiseSuppressionLevel = provider.config.noiseSuppressionLevel;
        _highPassFilterHz = provider.config.highPassFilterHz;
        _limiterEnabled = provider.config.limiterEnabled;
        _audioSourceMode = provider.config.audioSourceMode;
      });
    });
  }

  void _applyAudioPreset(String? preset) {
    if (preset == null) return;
    setState(() {
      _audioPreset = preset;
      _inputGainDb = 0;
      _limiterEnabled = true;
      _highPassFilterHz = 80;
      switch (preset) {
        case BroadcasterConfig.presetHematData:
          _bitrate = 32;
          _noiseSuppressionLevel = BroadcasterConfig.noiseLow;
          break;
        case BroadcasterConfig.presetJernih:
          _bitrate = 96;
          _noiseSuppressionLevel = BroadcasterConfig.noiseLow;
          break;
        case BroadcasterConfig.presetMaksimal:
          _bitrate = 128;
          _noiseSuppressionLevel = BroadcasterConfig.noiseOff;
          break;
        default:
          _bitrate = 64;
          _noiseSuppressionLevel = BroadcasterConfig.noiseLow;
      }
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
      audioPreset: _audioPreset,
      inputGainDb: _inputGainDb,
      noiseSuppressionLevel: _noiseSuppressionLevel,
      highPassFilterHz: _highPassFilterHz,
      limiterEnabled: _limiterEnabled,
      audioSourceMode: _audioSourceMode,
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

class _AudioQualitySection extends StatelessWidget {
  const _AudioQualitySection({
    required this.audioPreset,
    required this.inputGainDb,
    required this.noiseSuppressionLevel,
    required this.highPassFilterHz,
    required this.limiterEnabled,
    required this.audioSourceMode,
    required this.onPresetChanged,
    required this.onGainChanged,
    required this.onNoiseChanged,
    required this.onHighPassChanged,
    required this.onLimiterChanged,
    required this.onAudioSourceModeChanged,
  });

  final String audioPreset;
  final double inputGainDb;
  final String noiseSuppressionLevel;
  final int highPassFilterHz;
  final bool limiterEnabled;
  final String audioSourceMode;
  final ValueChanged<String?> onPresetChanged;
  final ValueChanged<double> onGainChanged;
  final ValueChanged<String?> onNoiseChanged;
  final ValueChanged<int?> onHighPassChanged;
  final ValueChanged<bool> onLimiterChanged;
  final ValueChanged<String?> onAudioSourceModeChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppTheme.forest),
                const SizedBox(width: 8),
                Text(
                  'Kualitas Audio',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: audioPreset,
              decoration: const InputDecoration(
                labelText: 'Preset Audio',
                prefixIcon: Icon(Icons.equalizer_rounded),
              ),
              items: const [
                DropdownMenuItem(
                  value: BroadcasterConfig.presetHematData,
                  child: Text(BroadcasterConfig.presetHematData),
                ),
                DropdownMenuItem(
                  value: BroadcasterConfig.presetStandarKajian,
                  child: Text(BroadcasterConfig.presetStandarKajian),
                ),
                DropdownMenuItem(
                  value: BroadcasterConfig.presetJernih,
                  child: Text(BroadcasterConfig.presetJernih),
                ),
                DropdownMenuItem(
                  value: BroadcasterConfig.presetMaksimal,
                  child: Text(BroadcasterConfig.presetMaksimal),
                ),
              ],
              onChanged: onPresetChanged,
            ),
            const SizedBox(height: 12),
            Text(
              'Input Gain ${inputGainDb.toStringAsFixed(1)} dB',
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            Slider(
              value: inputGainDb,
              min: -12,
              max: 12,
              divisions: 48,
              label: '${inputGainDb.toStringAsFixed(1)} dB',
              onChanged: onGainChanged,
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: noiseSuppressionLevel,
              decoration: const InputDecoration(
                labelText: 'Noise Suppression',
                prefixIcon: Icon(Icons.noise_control_off_rounded),
              ),
              items: const [
                DropdownMenuItem(
                  value: BroadcasterConfig.noiseOff,
                  child: Text(BroadcasterConfig.noiseOff),
                ),
                DropdownMenuItem(
                  value: BroadcasterConfig.noiseLow,
                  child: Text(BroadcasterConfig.noiseLow),
                ),
                DropdownMenuItem(
                  value: BroadcasterConfig.noiseMedium,
                  child: Text(BroadcasterConfig.noiseMedium),
                ),
                DropdownMenuItem(
                  value: BroadcasterConfig.noiseHigh,
                  child: Text(BroadcasterConfig.noiseHigh),
                ),
              ],
              onChanged: onNoiseChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: highPassFilterHz,
              decoration: const InputDecoration(
                labelText: 'High-pass Filter',
                prefixIcon: Icon(Icons.filter_alt_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Off')),
                DropdownMenuItem(value: 80, child: Text('80 Hz')),
                DropdownMenuItem(value: 100, child: Text('100 Hz')),
              ],
              onChanged: onHighPassChanged,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: limiterEnabled,
              onChanged: onLimiterChanged,
              title: const Text('Limiter'),
              secondary: const Icon(Icons.speed_rounded),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: audioSourceMode,
              decoration: const InputDecoration(
                labelText: 'Audio Source Mode',
                prefixIcon: Icon(Icons.mic_rounded),
              ),
              items: const [
                DropdownMenuItem(
                  value: BroadcasterConfig.audioSourceNatural,
                  child: Text('Natural / MIC'),
                ),
                DropdownMenuItem(
                  value: BroadcasterConfig.audioSourceVoiceProcessing,
                  child: Text('Voice Processing'),
                ),
              ],
              onChanged: onAudioSourceModeChanged,
            ),
            const SizedBox(height: 8),
            const Text(
              'Jika suara terdengar robotik, turunkan Noise Suppression atau pilih Natural.',
              style: TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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
