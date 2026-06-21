
import 'dart:convert';

enum TranscriptStatus { pending, processing, completed, failed }

class AiTranscriptJob {
  const AiTranscriptJob({
    required this.id,
    required this.recordingUploadId,
    required this.audioFilePath,
    required this.title,
    required this.ustadz,
    required this.createdAt,
    this.theme = '',
    this.status = TranscriptStatus.pending,
    this.languageHint = 'id-ar-mixed',
    this.transcriptText = '',
    this.summary = '',
    this.keyPoints = const [],
    this.keywords = const [],
    this.importantTimestamps = const [],
    this.errorMessage = '',
  });

  final String id;
  final String recordingUploadId;
  final String audioFilePath;
  final String title;
  final String theme;
  final String ustadz;
  final DateTime createdAt;
  final TranscriptStatus status;
  final String languageHint;
  final String transcriptText;
  final String summary;
  final List<String> keyPoints;
  final List<String> keywords;
  final List<String> importantTimestamps;
  final String errorMessage;

  AiTranscriptJob copyWith({TranscriptStatus? status, String? transcriptText, String? summary, List<String>? keyPoints, List<String>? keywords, List<String>? importantTimestamps, String? errorMessage}) => AiTranscriptJob(
    id: id, recordingUploadId: recordingUploadId, audioFilePath: audioFilePath, title: title,
    theme: theme, ustadz: ustadz, createdAt: createdAt, status: status ?? this.status,
    languageHint: languageHint, transcriptText: transcriptText ?? this.transcriptText,
    summary: summary ?? this.summary, keyPoints: keyPoints ?? this.keyPoints,
    keywords: keywords ?? this.keywords, importantTimestamps: importantTimestamps ?? this.importantTimestamps,
    errorMessage: errorMessage ?? this.errorMessage,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'recordingUploadId': recordingUploadId, 'audioFilePath': audioFilePath,
    'title': title, 'theme': theme, 'ustadz': ustadz, 'createdAt': createdAt.toIso8601String(),
    'status': status.name, 'languageHint': languageHint, 'transcriptText': transcriptText,
    'summary': summary, 'keyPoints': keyPoints, 'keywords': keywords,
    'importantTimestamps': importantTimestamps, 'errorMessage': errorMessage,
  };

  factory AiTranscriptJob.fromMap(Map<String, dynamic> map) => AiTranscriptJob(
    id: map['id'] as String? ?? '', recordingUploadId: map['recordingUploadId'] as String? ?? '',
    audioFilePath: map['audioFilePath'] as String? ?? '', title: map['title'] as String? ?? '',
    theme: map['theme'] as String? ?? '', ustadz: map['ustadz'] as String? ?? '',
    createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    status: TranscriptStatus.values.firstWhere((s) => s.name == map['status'], orElse: () => TranscriptStatus.pending),
    languageHint: map['languageHint'] as String? ?? 'id-ar-mixed', transcriptText: map['transcriptText'] as String? ?? '',
    summary: map['summary'] as String? ?? '', keyPoints: (map['keyPoints'] as List?)?.whereType<String>().toList() ?? [],
    keywords: (map['keywords'] as List?)?.whereType<String>().toList() ?? [],
    importantTimestamps: (map['importantTimestamps'] as List?)?.whereType<String>().toList() ?? [],
    errorMessage: map['errorMessage'] as String? ?? '',
  );

  String toJson() => jsonEncode(toMap());
  factory AiTranscriptJob.fromJson(String source) => AiTranscriptJob.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
