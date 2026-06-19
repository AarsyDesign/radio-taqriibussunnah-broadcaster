import 'package:permission_handler/permission_handler.dart';

enum MicrophonePermissionResult { granted, denied, permanentlyDenied }

class MicrophonePermissionService {
  Future<MicrophonePermissionResult> checkPermission() async {
    final status = await Permission.microphone.status;
    return _mapStatus(status);
  }

  Future<MicrophonePermissionResult> requestPermission() async {
    final status = await Permission.microphone.request();
    return _mapStatus(status);
  }

  MicrophonePermissionResult _mapStatus(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return MicrophonePermissionResult.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MicrophonePermissionResult.permanentlyDenied;
    }
    return MicrophonePermissionResult.denied;
  }
}
