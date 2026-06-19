import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/broadcaster_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_level_meter.dart';
import '../widgets/internet_monitor_card.dart';
import '../widgets/primary_live_button.dart';
import '../widgets/status_card.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  final _ustadzNameController = TextEditingController();
  final _kajianTitleController = TextEditingController();
  final _kajianThemeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BroadcasterProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Live Broadcast')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'Panel Siaran',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${provider.host}:${provider.port}${provider.mountPoint}',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                StatusCard(
                  status: provider.status,
                  duration: provider.duration,
                ),
                const SizedBox(height: 12),
                AudioLevelMeter(level: provider.audioLevel),
                const SizedBox(height: 12),
                _AudioQualityCard(
                  provider: provider,
                  onStartTest: () => _startTestRecording(context),
                  onPlay: () => _playTestRecording(context),
                  onDelete: () => _deleteTestRecording(context),
                ),
                const SizedBox(height: 12),
                InternetMonitorCard(provider: provider),
                const SizedBox(height: 16),
                _LiveMetadataFields(
                  ustadzNameController: _ustadzNameController,
                  kajianTitleController: _kajianTitleController,
                  kajianThemeController: _kajianThemeController,
                  enabled: !provider.isBusy && !provider.isLive,
                ),
                const SizedBox(height: 16),
                PrimaryLiveButton(
                  status: provider.status,
                  onStart: () => _startBroadcast(context),
                  onStop: () => _confirmStop(context),
                ),
              ],
            ),
    );
  }

  Future<void> _startBroadcast(BuildContext context) async {
    final provider = context.read<BroadcasterProvider>();
    final result = await provider.startBroadcast(
      ustadzName: _ustadzNameController.text,
      kajianTitle: _kajianTitleController.text,
      kajianTheme: _kajianThemeController.text,
    );
    if (!context.mounted) return;

    final message = switch (result) {
      StartBroadcastResult.started => null,
      StartBroadcastResult.missingConfig =>
        'Lengkapi konfigurasi di halaman Setup terlebih dahulu.',
      StartBroadcastResult.microphoneDenied =>
        'Izin microphone ditolak. Siaran tidak bisa dimulai.',
      StartBroadcastResult.microphonePermanentlyDenied =>
        'Izin microphone ditolak permanen. Aktifkan dari pengaturan Android.',
    };

    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmStop(BuildContext context) async {
    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Stop Siaran?'),
          content: const Text('Siaran live akan dihentikan untuk operator.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              child: const Text('Stop'),
            ),
          ],
        );
      },
    );

    if (shouldStop == true && context.mounted) {
      await context.read<BroadcasterProvider>().stopBroadcast();
    }
  }

  Future<void> _startTestRecording(BuildContext context) async {
    final provider = context.read<BroadcasterProvider>();
    final result = await provider.startTestRecording();
    if (!context.mounted) return;

    final message = switch (result) {
      TestRecordingStartResult.started =>
        provider.testRecording == null ? null : 'Tes rekam 15 detik selesai.',
      TestRecordingStartResult.microphoneDenied =>
        'Izin microphone ditolak. Tes rekam tidak bisa dimulai.',
      TestRecordingStartResult.microphonePermanentlyDenied =>
        'Izin microphone ditolak permanen. Aktifkan dari pengaturan Android.',
      TestRecordingStartResult.nativeUnavailable =>
        'Native recorder belum tersedia.',
    };

    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _playTestRecording(BuildContext context) async {
    final didPlay = await context
        .read<BroadcasterProvider>()
        .playTestRecording();
    if (!context.mounted || didPlay) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File rekaman tidak bisa diputar.')),
    );
  }

  Future<void> _deleteTestRecording(BuildContext context) async {
    final didDelete = await context
        .read<BroadcasterProvider>()
        .deleteTestRecording();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          didDelete
              ? 'File rekaman test dihapus.'
              : 'File rekaman gagal dihapus.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ustadzNameController.dispose();
    _kajianTitleController.dispose();
    _kajianThemeController.dispose();
    super.dispose();
  }
}

class _AudioQualityCard extends StatelessWidget {
  const _AudioQualityCard({
    required this.provider,
    required this.onStartTest,
    required this.onPlay,
    required this.onDelete,
  });

  final BroadcasterProvider provider;
  final VoidCallback onStartTest;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (provider.audioVolumeStatus) {
      'safe' => AppTheme.leaf,
      'clipping' => AppTheme.danger,
      _ => AppTheme.amber,
    };
    final recording = provider.testRecording;
    final canStartTest =
        !provider.isTestRecording && !provider.isLive && !provider.isBusy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.graphic_eq_rounded, color: AppTheme.forest),
                const SizedBox(width: 8),
                Text(
                  'Kualitas Audio',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.34)),
              ),
              child: Row(
                children: [
                  Icon(
                    provider.audioClipping
                        ? Icons.warning_amber_rounded
                        : Icons.mic_rounded,
                    color: statusColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.audioVolumeStatusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.audioVolumeStatusMessage,
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
            ),
            const SizedBox(height: 12),
            _DiagnosticRow(
              label: 'RMS',
              value: provider.audioRms.toStringAsFixed(3),
            ),
            _DiagnosticRow(
              label: 'Peak',
              value: provider.audioPeak.toStringAsFixed(3),
            ),
            _DiagnosticRow(
              label: 'Clipping',
              value: provider.audioClipping ? 'Ya' : 'Tidak',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: canStartTest ? onStartTest : null,
              icon: provider.isTestRecording
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fiber_manual_record_rounded),
              label: Text(
                provider.isTestRecording
                    ? 'Merekam 15 Detik...'
                    : 'Tes Rekam 15 Detik',
              ),
            ),
            if (recording != null) ...[
              const SizedBox(height: 14),
              _RecordingResult(
                fileName: recording.fileName,
                filePath: recording.filePath,
                sizeLabel: '${recording.sizeMb.toStringAsFixed(2)} MB',
                durationLabel: '${recording.durationSeconds} detik',
                onPlay: onPlay,
                onDelete: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingResult extends StatelessWidget {
  const _RecordingResult({
    required this.fileName,
    required this.filePath,
    required this.sizeLabel,
    required this.durationLabel,
    required this.onPlay,
    required this.onDelete,
  });

  final String fileName;
  final String filePath;
  final String sizeLabel;
  final String durationLabel;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fileName, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            filePath,
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(label: Text(sizeLabel)),
              Chip(label: Text(durationLabel)),
              IconButton.filledTonal(
                tooltip: 'Putar',
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow_rounded),
              ),
              IconButton.filledTonal(
                tooltip: 'Hapus',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveMetadataFields extends StatelessWidget {
  const _LiveMetadataFields({
    required this.ustadzNameController,
    required this.kajianTitleController,
    required this.kajianThemeController,
    required this.enabled,
  });

  final TextEditingController ustadzNameController;
  final TextEditingController kajianTitleController;
  final TextEditingController kajianThemeController;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: ustadzNameController,
              enabled: enabled,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Nama Ustadz',
                hintText: 'Contoh: Ustadz Abu Zaid',
                prefixIcon: Icon(Icons.person_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kajianTitleController,
              enabled: enabled,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Judul Kajian',
                hintText: 'Contoh: Kitab Tauhid',
                prefixIcon: Icon(Icons.menu_book_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kajianThemeController,
              enabled: enabled,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Tema Pembahasan',
                hintText: 'Contoh: Bab Takut Kepada Syirik',
                prefixIcon: Icon(Icons.topic_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Opsional. Jika diisi, akan tampil di aplikasi dan web sebagai info siaran live.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
