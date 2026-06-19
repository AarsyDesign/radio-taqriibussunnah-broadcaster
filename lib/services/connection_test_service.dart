import '../models/broadcaster_config.dart';

enum TestConnectionResult {
  idle,
  success,
  authenticationFailed,
  serverUnreachable,
}

class ConnectionTestService {
  Future<TestConnectionResult> test(BroadcasterConfig config) async {
    await Future<void>.delayed(const Duration(milliseconds: 850));

    final normalizedHost = config.host.toLowerCase();
    final normalizedUsername = config.username.toLowerCase();
    final normalizedPassword = config.password.toLowerCase();

    if (normalizedHost.contains('down') || normalizedHost.contains('offline')) {
      return TestConnectionResult.serverUnreachable;
    }

    if (normalizedUsername.contains('fail') || normalizedPassword == 'salah') {
      return TestConnectionResult.authenticationFailed;
    }

    return TestConnectionResult.success;
  }
}
