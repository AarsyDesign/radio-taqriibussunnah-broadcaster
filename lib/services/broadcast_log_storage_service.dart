import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/broadcast_log.dart';

class BroadcastLogStorageService {
  static const _logsKey = 'broadcast_logs';

  Future<List<BroadcastLog>> loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final rawLogs = prefs.getString(_logsKey);
    if (rawLogs == null || rawLogs.isEmpty) return [];

    try {
      final decoded = jsonDecode(rawLogs) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(BroadcastLog.fromMap)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveLogs(List<BroadcastLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(logs.map((log) => log.toMap()).toList());
    await prefs.setString(_logsKey, encoded);
  }

  Future<void> addLog(BroadcastLog log) async {
    final logs = await loadLogs();
    logs.insert(0, log);
    await saveLogs(logs);
  }

  Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logsKey);
  }
}
