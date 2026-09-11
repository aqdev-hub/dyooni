import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_exception.dart';
import '../../models/account.dart';

/// Talks to local storage only. No business rules — the Repository owns what an "account" means.
/// Phase-1 storage is local-only (SharedPreferences, JSON-encoded list); swapping this for a real
/// database (drift/sqlite) or Firestore later only touches this file — see repository-di.md.
class AccountsLocalDataSource {
  const AccountsLocalDataSource(this._prefs);
  final SharedPreferences _prefs;

  static const _key = 'accounts';

  Future<List<Account>> getAll() async {
    try {
      final raw = _prefs.getStringList(_key) ?? const [];
      return raw.map((s) => Account.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
    } catch (e) {
      throw StorageException(internalDetail: e.toString());
    }
  }

  Future<void> saveAll(List<Account> accounts) async {
    try {
      final raw = accounts.map((a) => jsonEncode(a.toJson())).toList();
      await _prefs.setStringList(_key, raw);
    } catch (e) {
      throw StorageException(internalDetail: e.toString());
    }
  }
}
