import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/auto_message_settings.dart';

/// Stores the global automatic-message settings and each account's override. Damaged data falls
/// back to defaults — these are preferences, never worth crashing the app over.
class AutoMessageLocalDataSource {
  const AutoMessageLocalDataSource(this._prefs);
  final SharedPreferences _prefs;

  static const _settingsKey = 'auto_message_settings_v1';
  static const _overridesKey = 'auto_message_overrides_v1';

  AutoMessageSettings getSettings() {
    try {
      final raw = _prefs.getString(_settingsKey);
      if (raw == null) return const AutoMessageSettings();
      return AutoMessageSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AutoMessageSettings();
    }
  }

  Future<void> saveSettings(AutoMessageSettings s) => _prefs.setString(_settingsKey, jsonEncode(s.toJson()));

  Map<String, AccountAutoMessage> getOverrides() {
    try {
      final raw = _prefs.getString(_overridesKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in decoded.entries) e.key: AccountAutoMessage.fromJson(e.value as Map<String, dynamic>)};
    } catch (_) {
      return {};
    }
  }

  Future<void> saveOverrides(Map<String, AccountAutoMessage> map) =>
      _prefs.setString(_overridesKey, jsonEncode({for (final e in map.entries) e.key: e.value.toJson()}));
}
