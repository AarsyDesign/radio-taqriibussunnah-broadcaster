
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recording_upload.dart';

class RecordingUploadService {
  static const _key = 'recording_upload_queue_v1';

  Future<List<RecordingUpload>> loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key)?.map(RecordingUpload.fromJson).toList() ?? [];
  }

  Future<void> saveQueue(List<RecordingUpload> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, queue.map((item) => item.toJson()).toList());
  }

  Future<RecordingUpload> markUploadPlaceholder(RecordingUpload item) async {
    // Supabase/VPS/S3 upload will replace this placeholder when credentials/backend are ready.
    return item.copyWith(status: RecordingUploadStatus.pending, errorMessage: 'Upload backend belum dikonfigurasi. Siap untuk Supabase Storage.');
  }
}
