
import 'dart:convert';

enum RecordingUploadStatus { pending, uploading, uploaded, failed }

class RecordingUpload {
  const RecordingUpload({
    required this.id,
    required this.filePath,
    required this.title,
    required this.ustadz,
    required this.recordedAt,
    required this.fileBytes,
    this.theme = '',
    this.durationSeconds = 0,
    this.status = RecordingUploadStatus.pending,
    this.remoteUrl = '',
    this.errorMessage = '',
  });

  final String id;
  final String filePath;
  final String title;
  final String theme;
  final String ustadz;
  final DateTime recordedAt;
  final int durationSeconds;
  final int fileBytes;
  final RecordingUploadStatus status;
  final String remoteUrl;
  final String errorMessage;

  RecordingUpload copyWith({RecordingUploadStatus? status, String? remoteUrl, String? errorMessage}) => RecordingUpload(
    id: id, filePath: filePath, title: title, theme: theme, ustadz: ustadz, recordedAt: recordedAt,
    durationSeconds: durationSeconds, fileBytes: fileBytes, status: status ?? this.status,
    remoteUrl: remoteUrl ?? this.remoteUrl, errorMessage: errorMessage ?? this.errorMessage,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'filePath': filePath, 'title': title, 'theme': theme, 'ustadz': ustadz,
    'recordedAt': recordedAt.toIso8601String(), 'durationSeconds': durationSeconds,
    'fileBytes': fileBytes, 'status': status.name, 'remoteUrl': remoteUrl, 'errorMessage': errorMessage,
  };

  factory RecordingUpload.fromMap(Map<String, dynamic> map) => RecordingUpload(
    id: map['id'] as String? ?? '', filePath: map['filePath'] as String? ?? '',
    title: map['title'] as String? ?? '', theme: map['theme'] as String? ?? '', ustadz: map['ustadz'] as String? ?? '',
    recordedAt: DateTime.tryParse(map['recordedAt'] as String? ?? '') ?? DateTime.now(),
    durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0, fileBytes: (map['fileBytes'] as num?)?.toInt() ?? 0,
    status: RecordingUploadStatus.values.firstWhere((s) => s.name == map['status'], orElse: () => RecordingUploadStatus.pending),
    remoteUrl: map['remoteUrl'] as String? ?? '', errorMessage: map['errorMessage'] as String? ?? '',
  );

  String toJson() => jsonEncode(toMap());
  factory RecordingUpload.fromJson(String source) => RecordingUpload.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
