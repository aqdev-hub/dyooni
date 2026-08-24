import '../../local/transactions/transactions_local_datasource.dart';
import '../../models/transaction.dart';
import '../../remote/firestore/transactions_firestore_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'transactions_repository.dart';

class TransactionsFirestoreRepositoryImpl implements TransactionsRepository {
  TransactionsFirestoreRepositoryImpl(this._cloud, this._legacy, this._prefs, this._userId);
  final TransactionsFirestoreDataSource _cloud;
  final TransactionsLocalDataSource _legacy;
  final SharedPreferences _prefs;
  final String? _userId;
  bool _migrated = false;

  Future<void> _migrateOnce() async {
    final key = 'firestore_transactions_migrated_${_userId ?? 'anonymous'}';
    if (_migrated || _prefs.getBool(key) == true) return;
    final legacy = await _legacy.getAll();
    for (final transaction in legacy) {
      await _cloud.save(transaction);
    }
    _migrated = true;
    await _prefs.setBool(key, true);
  }

  @override
  Future<List<Transaction>> getTransactions() async {
    await _migrateOnce();
    return _cloud.getAll();
  }

  @override
  Stream<List<Transaction>> watchTransactions() async* {
    await _migrateOnce();
    yield* _cloud.watchAll();
  }

  @override
  Future<void> addTransaction(Transaction transaction) async {
    await _migrateOnce();
    await _cloud.save(transaction);
  }

  @override
  Future<void> deleteTransactionsForAccount(String accountId) async {
    await _migrateOnce();
    await _cloud.deleteForAccount(accountId);
  }
}
