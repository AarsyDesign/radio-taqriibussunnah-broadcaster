// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:broadcaster/app.dart';
import 'package:broadcaster/models/broadcast_log.dart';
import 'package:broadcaster/models/broadcaster_config.dart';
import 'package:broadcaster/services/broadcast_log_storage_service.dart';
import 'package:broadcaster/services/config_storage_service.dart';
import 'package:broadcaster/services/native_broadcast_service.dart';
import 'package:broadcaster/services/network_info_service.dart';
import 'package:broadcaster/providers/broadcaster_provider.dart';
import 'package:broadcaster/models/connection_status.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Broadcaster app shows live controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => BroadcasterProvider(
          configStorageService: _FakeConfigStorageService(),
          logStorageService: _FakeBroadcastLogStorageService(),
          nativeBroadcastService: _FakeNativeBroadcastService(),
          networkInfoService: _FakeNetworkInfoService(),
        ),
        child: const BroadcasterApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Live Broadcast'), findsOneWidget);
    expect(find.text('Monitoring Internet'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Mulai Siaran'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mulai Siaran'), findsOneWidget);
  });
}

class _FakeConfigStorageService extends ConfigStorageService {
  @override
  Future<BroadcasterConfig> loadConfig() async {
    return const BroadcasterConfig(
      host: 'radio.test',
      port: 8000,
      mountPoint: '/live',
      username: 'operator',
      password: 'secret',
      bitrate: 96,
      audioInput: 'Mic HP',
    );
  }
}

class _FakeBroadcastLogStorageService extends BroadcastLogStorageService {
  @override
  Future<List<BroadcastLog>> loadLogs() async => [];
}

class _FakeNetworkInfoService extends NetworkInfoService {
  @override
  Future<String> getNetworkType() async => 'WiFi';
}

class _FakeNativeBroadcastService extends NativeBroadcastService {
  @override
  Stream<ConnectionStatus> get statusStream => const Stream.empty();

  @override
  Stream<double> get audioLevelStream => const Stream.empty();

  @override
  Future<ConnectionStatus?> getServiceStatus() async =>
      ConnectionStatus.offline;
}
