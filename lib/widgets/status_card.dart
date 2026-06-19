import 'package:flutter/material.dart';

import '../models/connection_status.dart';
import '../theme/app_theme.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.status, required this.duration});

  final ConnectionStatus status;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_statusIcon(status), color: color, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.label,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(color: color),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        status.detail,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: AppTheme.cream,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Durasi Siaran',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDuration(duration),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(ConnectionStatus status) {
    return switch (status) {
      ConnectionStatus.live => AppTheme.leaf,
      ConnectionStatus.liveRestored => AppTheme.leaf,
      ConnectionStatus.connecting ||
      ConnectionStatus.networkLost ||
      ConnectionStatus.reconnecting => AppTheme.amber,
      ConnectionStatus.offline || ConnectionStatus.stopped => AppTheme.muted,
      ConnectionStatus.authenticationFailed ||
      ConnectionStatus.serverUnreachable ||
      ConnectionStatus.microphoneDenied ||
      ConnectionStatus.connectionDropped ||
      ConnectionStatus.reconnectFailed ||
      ConnectionStatus.timeout ||
      ConnectionStatus.invalidConfig ||
      ConnectionStatus.protocolRejected ||
      ConnectionStatus.unsupportedCodec ||
      ConnectionStatus.unknownError => AppTheme.danger,
    };
  }

  IconData _statusIcon(ConnectionStatus status) {
    return switch (status) {
      ConnectionStatus.live => Icons.podcasts_rounded,
      ConnectionStatus.liveRestored => Icons.podcasts_rounded,
      ConnectionStatus.connecting => Icons.sync_rounded,
      ConnectionStatus.networkLost =>
        Icons.signal_wifi_connected_no_internet_4_rounded,
      ConnectionStatus.reconnecting => Icons.wifi_find_rounded,
      ConnectionStatus.offline => Icons.radio_button_unchecked_rounded,
      ConnectionStatus.stopped => Icons.stop_circle_outlined,
      ConnectionStatus.authenticationFailed => Icons.lock_person_rounded,
      ConnectionStatus.serverUnreachable => Icons.cloud_off_rounded,
      ConnectionStatus.microphoneDenied => Icons.mic_off_rounded,
      ConnectionStatus.connectionDropped =>
        Icons.signal_wifi_connected_no_internet_4_rounded,
      ConnectionStatus.reconnectFailed => Icons.wifi_off_rounded,
      ConnectionStatus.timeout => Icons.timer_off_rounded,
      ConnectionStatus.invalidConfig => Icons.rule_folder_rounded,
      ConnectionStatus.protocolRejected => Icons.sync_problem_rounded,
      ConnectionStatus.unsupportedCodec => Icons.volume_off_rounded,
      ConnectionStatus.unknownError => Icons.error_outline_rounded,
    };
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
