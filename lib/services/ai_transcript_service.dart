
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_transcript.dart';
import '../models/recording_upload.dart';

class AiTranscriptService {
  static const _key = 'ai_transcript_jobs_v1';

  Future<List<AiTranscriptJob>> loadJobs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key)?.map(AiTranscriptJob.fromJson).toList() ?? [];
  }

  Future<void> saveJobs(List<AiTranscriptJob> jobs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, jobs.map((job) => job.toJson()).toList());
  }

  AiTranscriptJob createJobFromRecording(RecordingUpload recording) => AiTranscriptJob(
    id: '${recording.id}-transcript',
    recordingUploadId: recording.id,
    audioFilePath: recording.filePath,
    title: recording.title,
    theme: recording.theme,
    ustadz: recording.ustadz,
    createdAt: DateTime.now(),
  );

  Future<AiTranscriptJob> markBackendPending(AiTranscriptJob job) async {
    return job.copyWith(
      status: TranscriptStatus.pending,
      errorMessage: 'AI backend belum dikonfigurasi. Siap untuk Whisper/OpenAI/self-hosted pipeline.',
    );
  }
}
