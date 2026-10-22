import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_exception.dart';
import '../../models/category_type.dart';

/// SharedPreferences only, like every other `data/local/*` datasource. What "nothing saved yet"
/// means (the three default rows) is decided by the provider.
class CategoriesLocalDataSource {
  const CategoriesLocalDataSource(this._prefs);
  final SharedPreferences _prefs;

  static const _key = 'category_types_v1';

  /// `null` when nothing was saved OR the stored text is unreadable — a damaged list degrades to
  /// the defaults instead of crashing every screen that reads categories.
  List<CategoryType>? get() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as List<dynamic>;
      return [for (final item in decoded) CategoryType.fromJson(item as Map<String, dynamic>)];
    } catch (_) {
      return null;
    }
  }

  Future<void> save(List<CategoryType> categories) async {
    try {
      await _prefs.setString(_key, jsonEncode([for (final c in categories) c.toJson()]));
    } catch (e) {
      throw StorageException(internalDetail: e.toString());
    }
  }
}
