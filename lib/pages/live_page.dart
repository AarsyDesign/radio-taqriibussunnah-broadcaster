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

  @override
  void dispose() {
    _ustadzNameController.dispose();
    _kajianTitleController.dispose();
    _kajianThemeController.dispose();
    super.dispose();
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
