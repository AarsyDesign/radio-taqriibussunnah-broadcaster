import 'package:flutter/material.dart';

import '../providers/broadcaster_provider.dart';
import '../theme/app_theme.dart';

class InternetMonitorCard extends StatelessWidget {
  const InternetMonitorCard({super.key, required this.provider});

  final BroadcasterProvider provider;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.network_check_rounded, color: AppTheme.forest),
                const SizedBox(width: 8),
                Text(
                  'Monitoring Internet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _MonitorRow(
              label: 'Upload keluar',
              value: '${provider.totalUploadMb.toStringAsFixed(2)} MB',
            ),
            _MonitorRow(
              label: 'Kecepatan upload',
              value: '${provider.uploadSpeedKbps.toStringAsFixed(1)} kbps',
            ),
            _MonitorRow(
              label: 'Rata-rata upload',
              value: '${provider.averageUploadKbps.toStringAsFixed(1)} kbps',
            ),
            _MonitorRow(
              label: 'Estimasi data per jam',
              value: '${provider.estimatedDataPerHourMb.toStringAsFixed(1)} MB',
            ),
            _MonitorRow(label: 'Jenis jaringan', value: provider.networkType),
            _MonitorRow(
              label: 'Jumlah reconnect',
              value: provider.reconnectCount.toString(),
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitorRow extends StatelessWidget {
  const _MonitorRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12, top: 2),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppTheme.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
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
