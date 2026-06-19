import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/broadcast_log.dart';
import '../models/connection_status.dart';
import '../providers/broadcaster_provider.dart';
import '../theme/app_theme.dart';

class LogPage extends StatelessWidget {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<BroadcasterProvider>().logs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Siaran'),
        actions: [
          IconButton(
            tooltip: 'Hapus log',
            onPressed: logs.isEmpty ? null : () => _confirmClearLogs(context),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: logs.isEmpty ? 2 : logs.length + 1,
        separatorBuilder: (_, index) => index == 0
            ? const SizedBox(height: 16)
            : const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Riwayat Broadcast',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Log dummy disimpan lokal di perangkat operator.',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          }

          if (logs.isEmpty) {
            return const _EmptyLogState();
          }

          return _LogCard(log: logs[index - 1]);
        },
      ),
    );
  }

  Future<void> _confirmClearLogs(BuildContext context) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus semua log?'),
          content: const Text('Riwayat dummy lokal akan dikosongkan.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (shouldClear == true && context.mounted) {
      await context.read<BroadcasterProvider>().clearLogs();
    }
  }
}

class _EmptyLogState extends StatelessWidget {
  const _EmptyLogState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.forest.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: AppTheme.forest,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Belum ada riwayat siaran. Log akan tersimpan saat operator menghentikan siaran.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});

  final BroadcastLog log;

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
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.forest.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: AppTheme.forest,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live mulai ${_formatDateTime(log.startedAt)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Stop ${_formatDateTime(log.stoppedAt)}',
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
            const SizedBox(height: 14),
            _LogRow(label: 'Durasi', value: _formatDuration(log.duration)),
            _LogRow(
              label: 'Total upload',
              value: '${log.totalUploadMb.toStringAsFixed(1)} MB',
            ),
            _LogRow(
              label: 'Jumlah reconnect',
              value: log.reconnectCount.toString(),
            ),
            _LogRow(
              label: 'Status akhir',
              value: log.finalStatus.label,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/${dateTime.year} $hour:$minute';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) return '$minutes menit';
    return '$hours jam $minutes menit';
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({
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
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10, top: 2),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
