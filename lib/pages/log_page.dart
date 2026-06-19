import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_changelog.dart';
import '../models/build_info_model.dart';
import '../models/broadcast_log.dart';
import '../models/connection_status.dart';
import '../providers/broadcaster_provider.dart';
import '../services/build_info_service.dart';
import '../theme/app_theme.dart';

class LogPage extends StatelessWidget {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BroadcasterProvider>();
    final logs = provider.logs;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Log'),
          actions: [
            IconButton(
              tooltip: 'Hapus log',
              onPressed: logs.isEmpty ? null : () => _confirmClearLogs(context),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Riwayat'),
              Tab(text: 'Connection Debug'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BroadcastHistoryTab(logs: logs),
            _ConnectionDebugTab(messages: provider.nativeLogMessages),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearLogs(BuildContext context) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus semua log?'),
          content: const Text('Riwayat lokal akan dikosongkan.'),
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

class _BroadcastHistoryTab extends StatelessWidget {
  _BroadcastHistoryTab({required this.logs});

  final List<BroadcastLog> logs;
  final BuildInfoService _buildInfoService = BuildInfoService();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: logs.isEmpty ? 3 : logs.length + 2,
      separatorBuilder: (_, index) =>
          index == 0 ? const SizedBox(height: 16) : const SizedBox(height: 12),
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
                'Log lokal disimpan di perangkat operator.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }

        final buildInfoIndex = logs.isEmpty ? 2 : logs.length + 1;
        if (index == buildInfoIndex) {
          return FutureBuilder<BuildInfoModel>(
            future: _buildInfoService.loadBuildInfo(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              return _BuildInfoCard(buildInfo: snapshot.data!);
            },
          );
        }

        if (logs.isEmpty) {
          return const _EmptyLogState();
        }

        return _LogCard(log: logs[index - 1]);
      },
    );
  }
}

class _BuildInfoCard extends StatelessWidget {
  const _BuildInfoCard({required this.buildInfo});

  final BuildInfoModel buildInfo;

  @override
  Widget build(BuildContext context) {
    final latestChangelog = appChangelog.first;
    final notes = (latestChangelog['notes'] as List<String>).take(5).toList();

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
                  child: const Icon(Icons.info_outline, color: AppTheme.forest),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Informasi Build',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _LogRow(label: 'App Name', value: buildInfo.appName),
            _LogRow(label: 'Version', value: buildInfo.versionName),
            _LogRow(label: 'Build', value: buildInfo.buildNumber),
            _LogRow(label: 'Channel', value: buildInfo.buildChannel),
            _LogRow(label: 'Patch', value: buildInfo.patchName),
            _LogRow(label: 'Environment', value: buildInfo.environment),
            _LogRow(label: 'Build Date', value: buildInfo.buildDate),
            _LogRow(label: 'Commit', value: buildInfo.gitCommit, isLast: true),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _copyBuildInfo(context),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Salin Info Build'),
            ),
            const SizedBox(height: 16),
            Text('Changelog', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _LogRow(label: 'Patch', value: latestChangelog['patch'].toString()),
            _LogRow(label: 'Date', value: latestChangelog['date'].toString()),
            const SizedBox(height: 6),
            ...notes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: AppTheme.muted)),
                    Expanded(
                      child: Text(
                        note,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyBuildInfo(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(
        text:
            '${buildInfo.appName}\n'
            'Version: ${buildInfo.versionName}\n'
            'Build: ${buildInfo.buildNumber}\n'
            'Channel: ${buildInfo.buildChannel}\n'
            'Patch: ${buildInfo.patchName}\n'
            'Environment: ${buildInfo.environment}\n'
            'Build Date: ${buildInfo.buildDate}\n'
            'Commit: ${buildInfo.gitCommit}',
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Info build berhasil disalin.')),
    );
  }
}

class _ConnectionDebugTab extends StatelessWidget {
  const _ConnectionDebugTab({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: messages.isEmpty ? 2 : messages.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connection Debug',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              const Text(
                'Validation, DNS, socket, handshake, response, dan auth.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }

        if (messages.isEmpty) {
          return const _EmptyDebugState();
        }

        return _DebugLogCard(message: messages[index - 1]);
      },
    );
  }
}

class _EmptyDebugState extends StatelessWidget {
  const _EmptyDebugState();

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
                color: AppTheme.amber.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.terminal_rounded, color: AppTheme.amber),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Tekan Tes Koneksi atau Mulai Siaran untuk melihat log debug koneksi.',
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

class _DebugLogCard extends StatelessWidget {
  const _DebugLogCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: SelectableText(
          message,
          style: const TextStyle(
            color: AppTheme.forest,
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
    );
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
            _LogRow(label: 'Nama Ustadz', value: _emptyDash(log.ustadzName)),
            _LogRow(label: 'Judul Kajian', value: _emptyDash(log.kajianTitle)),
            _LogRow(
              label: 'Tema Pembahasan',
              value: _emptyDash(log.kajianTheme),
            ),
            _LogRow(
              label: 'Metadata terkirim',
              value: _emptyDash(log.liveMetadata),
            ),
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
              label: 'Ukuran rekaman',
              value: '${log.recordingMb.toStringAsFixed(1)} MB',
            ),
            if (log.recordingFilePath.isNotEmpty)
              _LogRow(
                label: 'File rekaman',
                value: log.recordingFilePath.split(RegExp(r'[\\/]')).last,
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

  String _emptyDash(String value) {
    return value.trim().isEmpty ? '-' : value;
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
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
