import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/connection_status.dart';
import '../providers/broadcaster_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_level_meter.dart';
import '../widgets/internet_monitor_card.dart';
import '../widgets/primary_live_button.dart';
import '../widgets/status_card.dart';

class LivePage extends StatelessWidget {
  const LivePage({super.key});

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
                PrimaryLiveButton(
                  status: provider.status,
                  onStart: () => _startBroadcast(context),
                  onStop: () => _confirmStop(context),
                ),
                const SizedBox(height: 14),
                _DummyStatusControls(provider: provider),
              ],
            ),
    );
  }

  Future<void> _startBroadcast(BuildContext context) async {
    final provider = context.read<BroadcasterProvider>();
    final result = await provider.startBroadcast();
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
}

class _DummyStatusControls extends StatelessWidget {
  const _DummyStatusControls({required this.provider});

  final BroadcasterProvider provider;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Dummy',
              style: TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in ConnectionStatus.values)
                  ChoiceChip(
                    label: Text(status.label),
                    selected: provider.status == status,
                    onSelected: (_) => provider.simulateStatus(status),
                    selectedColor: const Color(0xFFE5EEDA),
                    labelStyle: TextStyle(
                      color: provider.status == status
                          ? AppTheme.forest
                          : AppTheme.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
