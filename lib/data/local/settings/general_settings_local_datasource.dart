import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_exception.dart';
import '../../models/general_settings.dart';

/// يتحدث مع SharedPreferences فقط — لا قواعد عمل هنا، تمامًا كنمط
/// data/local/settings/personal_data_local_datasource.dart المُتّبع في هذا المشروع.
class GeneralSettingsLocalDataSource {
  const GeneralSettingsLocalDataSource(this._prefs);
  final SharedPreferences _prefs;

  static const _key = 'general_settings';

  Future<GeneralSettings?> get() async {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return null;
      return GeneralSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      throw StorageException(internalDetail: e.toString());
    }
  }

  Future<void> save(GeneralSettings settings) async {
    try {
      await _prefs.setString(_key, jsonEncode(settings.toJson()));
    } catch (e) {
      throw StorageException(internalDetail: e.toString());
    }
  }
}
