import 'dart:convert';

import 'connection_status.dart';

class BroadcastLog {
  const BroadcastLog({
    required this.id,
    required this.startedAt,
    required this.stoppedAt,
    required this.durationSeconds,
    required this.totalUploadBytes,
    required this.reconnectCount,
    required this.finalStatus,
  });

  final String id;
  final DateTime startedAt;
  final DateTime stoppedAt;
  final int durationSeconds;
  final int totalUploadBytes;
  final int reconnectCount;
  final ConnectionStatus finalStatus;

  Duration get duration => Duration(seconds: durationSeconds);
  double get totalUploadMb => totalUploadBytes / 1024 / 1024;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startedAt': startedAt.toIso8601String(),
      'stoppedAt': stoppedAt.toIso8601String(),
      'durationSeconds': durationSeconds,
      'totalUploadBytes': totalUploadBytes,
      'reconnectCount': reconnectCount,
      'finalStatus': finalStatus.name,
    };
  }

  factory BroadcastLog.fromMap(Map<String, dynamic> map) {
    return BroadcastLog(
      id: map['id'] as String? ?? '',
      startedAt:
          DateTime.tryParse(map['startedAt'] as String? ?? '') ?? DateTime(0),
      stoppedAt:
          DateTime.tryParse(map['stoppedAt'] as String? ?? '') ?? DateTime(0),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      totalUploadBytes: (map['totalUploadBytes'] as num?)?.toInt() ?? 0,
      reconnectCount: (map['reconnectCount'] as num?)?.toInt() ?? 0,
      finalStatus: ConnectionStatus.values.firstWhere(
        (status) => status.name == map['finalStatus'],
        orElse: () => ConnectionStatus.stopped,
      ),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory BroadcastLog.fromJson(String source) {
    return BroadcastLog.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}
