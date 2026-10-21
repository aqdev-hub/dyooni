import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_exception.dart';
import '../../models/currency_type.dart';

/// Talks to SharedPreferences only — same role as the other `data/local/*` datasources. No rules
/// here: what "nothing saved yet" means (the two default currencies) is decided by the provider.
class CurrenciesLocalDataSource {
  const CurrenciesLocalDataSource(this._prefs);
  final SharedPreferences _prefs;

  static const _key = 'currency_types_v1';

  /// `null` when nothing was ever saved OR the stored text is unreadable — a damaged list must
  /// degrade to the defaults, never crash the screens that read currencies on every build.
  List<CurrencyType>? get() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as List<dynamic>;
      return [for (final item in decoded) CurrencyType.fromJson(item as Map<String, dynamic>)];
    } catch (_) {
      return null;
    }
  }

  Future<void> save(List<CurrencyType> currencies) async {
    try {
      await _prefs.setString(_key, jsonEncode([for (final c in currencies) c.toJson()]));
    } catch (e) {
      throw StorageException(internalDetail: e.toString());
    }
  }
}
