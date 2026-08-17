import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-first queue used to record changes that can later be sent to a
/// remote synchronization backend. The app remains fully usable offline.
class SyncQueue {
  static const _key = 'offline_sync_queue_v1';

  static Future<List<Map<String, dynamic>>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map((entry) => jsonDecode(entry))
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  static Future<void> enqueue({
    required String entity,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key)?.toList() ?? <String>[];
    raw.add(jsonEncode({
      'id': '${DateTime.now().microsecondsSinceEpoch}-$entity',
      'entity': entity,
      'operation': operation,
      'payload': payload,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'attempts': 0,
    }));
    await prefs.setStringList(_key, raw);
  }

  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key)?.toList() ?? <String>[];
    raw.removeWhere((entry) {
      final decoded = jsonDecode(entry);
      return decoded is Map && decoded['id'] == id;
    });
    await prefs.setStringList(_key, raw);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
