import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// When each kind of message was last sent to each account ("accountId|template" → time).
/// Only a convenience (it shows "آخر إرسال" on the message sheet), so a damaged value is simply
/// treated as "never sent".
class MessageLogLocalDataSource {
  const MessageLogLocalDataSource(this._prefs);
  final SharedPreferences _prefs;

  static const _key = 'message_log_v1';

  Map<String, DateTime> get() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in decoded.entries)
          if (DateTime.tryParse(e.value as String) != null) e.key: DateTime.parse(e.value as String),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, DateTime> log) async {
    try {
      await _prefs.setString(_key, jsonEncode({for (final e in log.entries) e.key: e.value.toIso8601String()}));
    } catch (_) {
      // Best effort: failing to remember "last sent" must never block sending.
    }
  }
}
