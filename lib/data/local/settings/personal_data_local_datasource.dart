import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_exception.dart';
import '../../models/personal_data.dart';

/// Talks to local storage only. No business rules — the Repository decides what "nothing saved
/// yet" means (see PersonalDataRepositoryImpl, which falls back to PersonalData.dyooniDefault).
class PersonalDataLocalDataSource {
  const PersonalDataLocalDataSource(this._prefs);
  final SharedPreferences _prefs;

  static const _key = 'personal_data';

  Future<PersonalData?> get() async {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return null;
      return PersonalData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      throw StorageException(internalDetail: e.toString());
    }
  }

  Future<void> save(PersonalData data) async {
    try {
      await _prefs.setString(_key, jsonEncode(data.toJson()));
    } catch (e) {
      throw StorageException(internalDetail: e.toString());
    }
  }
}
