import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/account_reminder.dart';

class RemindersLocalDataSource {
  const RemindersLocalDataSource(this._prefs);
  final SharedPreferences _prefs;

  static const _key = 'account_reminders_v1';
  static const _counterKey = 'account_reminders_counter_v1';

  List<AccountReminder> get() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return [];
      return [for (final item in jsonDecode(raw) as List<dynamic>) AccountReminder.fromJson(item as Map<String, dynamic>)];
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<AccountReminder> reminders) =>
      _prefs.setString(_key, jsonEncode([for (final r in reminders) r.toJson()]));

  /// Next unused notification base. Never reused, so cancelling an old reminder can never cancel
  /// a newer one's notifications.
  Future<int> nextBase() async {
    final next = (_prefs.getInt(_counterKey) ?? 0) + 1;
    await _prefs.setInt(_counterKey, next);
    return next;
  }
}
