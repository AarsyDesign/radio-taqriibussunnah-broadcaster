
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/content_sync_payload.dart';

class ContentSyncService {
  static const _stateKey = 'content_sync_state_v1';

  Future<ContentSyncState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    if (raw == null || raw.isEmpty) return const ContentSyncState();
    try {
      return ContentSyncState.fromJson(raw);
    } catch (_) {
      return const ContentSyncState();
    }
  }

  Future<void> saveState(ContentSyncState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, state.toJson());
  }

  Future<ContentSyncState> saveEndpoint(String endpointUrl) async {
    final current = await loadState();
    final next = current.copyWith(endpointUrl: endpointUrl.trim(), lastStatus: 'configured', lastError: '');
    await saveState(next);
    return next;
  }

  Future<ContentSyncState> sync(ContentSyncPayload payload) async {
    final state = await loadState();
    if (state.endpointUrl.isEmpty) {
      final next = state.copyWith(lastStatus: 'skipped', lastError: 'Endpoint sync belum dikonfigurasi.');
      await saveState(next);
      return next;
    }

    try {
      final uri = Uri.parse(state.endpointUrl);
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload.toMap()));
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final next = state.copyWith(lastStatus: 'failed', lastError: 'HTTP ${response.statusCode}: $body');
        await saveState(next);
        return next;
      }

      final next = state.copyWith(lastStatus: payload.isLive ? 'live_synced' : 'offline_synced', lastError: '', lastSyncedAt: DateTime.now());
      await saveState(next);
      return next;
    } catch (error) {
      final next = state.copyWith(lastStatus: 'failed', lastError: error.toString());
      await saveState(next);
      return next;
    }
  }
}
