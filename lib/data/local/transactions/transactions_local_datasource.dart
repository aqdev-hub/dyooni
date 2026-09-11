import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_exception.dart';
import '../../models/transaction.dart';

/// Talks to local storage only. No business rules — the Repository owns what a "transaction"
/// means and how it relates to an account's balance.
class TransactionsLocalDataSource {
  const TransactionsLocalDataSource(this._prefs);
  final SharedPreferences _prefs;

  static const _key = 'transactions';

  Future<List<Transaction>> getAll() async {
    try {
      final raw = _prefs.getStringList(_key) ?? const [];
      return raw.map((s) => Transaction.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
    } catch (e) {
      throw StorageException(internalDetail: e.toString());
    }
  }

  Future<void> saveAll(List<Transaction> transactions) async {
    try {
      final raw = transactions.map((t) => jsonEncode(t.toJson())).toList();
      await _prefs.setStringList(_key, raw);
    } catch (e) {
      throw StorageException(internalDetail: e.toString());
    }
  }
}
