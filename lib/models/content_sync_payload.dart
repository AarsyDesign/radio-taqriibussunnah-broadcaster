
import 'dart:convert';

class ContentSyncPayload {
  const ContentSyncPayload({
    required this.isLive,
    required this.title,
    required this.theme,
    required this.ustadz,
    required this.liveMetadata,
    required this.updatedAt,
    this.startedAt,
    this.stoppedAt,
  });

  final bool isLive;
  final String title;
  final String theme;
  final String ustadz;
  final String liveMetadata;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? stoppedAt;

  Map<String, dynamic> toMap() => {
    'is_live': isLive,
    'title': title,
    'theme': theme,
    'ustadz': ustadz,
    'live_metadata': liveMetadata,
    'updated_at': updatedAt.toIso8601String(),
    'started_at': startedAt?.toIso8601String(),
    'stopped_at': stoppedAt?.toIso8601String(),
  };

  String toJson() => jsonEncode(toMap());
}

class ContentSyncState {
  const ContentSyncState({
    this.endpointUrl = '',
    this.lastStatus = 'idle',
    this.lastError = '',
    this.lastSyncedAt,
  });

  final String endpointUrl;
  final String lastStatus;
  final String lastError;
  final DateTime? lastSyncedAt;

  ContentSyncState copyWith({
    String? endpointUrl,
    String? lastStatus,
    String? lastError,
    DateTime? lastSyncedAt,
  }) => ContentSyncState(
    endpointUrl: endpointUrl ?? this.endpointUrl,
    lastStatus: lastStatus ?? this.lastStatus,
    lastError: lastError ?? this.lastError,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );

  Map<String, dynamic> toMap() => {
    'endpointUrl': endpointUrl,
    'lastStatus': lastStatus,
    'lastError': lastError,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
  };

  factory ContentSyncState.fromMap(Map<String, dynamic> map) => ContentSyncState(
    endpointUrl: map['endpointUrl'] as String? ?? '',
    lastStatus: map['lastStatus'] as String? ?? 'idle',
    lastError: map['lastError'] as String? ?? '',
    lastSyncedAt: DateTime.tryParse(map['lastSyncedAt'] as String? ?? ''),
  );

  String toJson() => jsonEncode(toMap());
  factory ContentSyncState.fromJson(String source) => ContentSyncState.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
