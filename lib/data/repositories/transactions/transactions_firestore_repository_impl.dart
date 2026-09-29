import 'dart:async';

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
    _migrated = true;
    await _prefs.setBool(key, true);
    for (final transaction in legacy) {
      unawaited(_sync(() => _cloud.save(transaction)));
    }
  }

  Future<void> _sync(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // The local write has succeeded; cloud synchronization is retried by Firestore later.
    }
  }

  Future<void> _upsertLocal(Transaction transaction) async {
    final stamped = Transaction(
      id: transaction.id,
      accountId: transaction.accountId,
      amount: transaction.amount,
      currency: transaction.currency,
      direction: transaction.direction,
      date: transaction.date,
      details: transaction.details,
      attachmentPath: transaction.attachmentPath,
      voiceRecording: transaction.voiceRecording,
      updatedAt: DateTime.now(),
    );
    final current = await _legacy.getAll();
    final index = current.indexWhere((value) => value.id == stamped.id);
    if (index < 0) {
      await _legacy.saveAll([...current, stamped]);
    } else {
      current[index] = stamped;
      await _legacy.saveAll(current);
    }
  }

  /// Preserve a local write while Firestore is offline or still delivering an older snapshot.
  Future<List<Transaction>> _mergeCloudSnapshot(List<Transaction> cloudTransactions) async {
    final local = await _legacy.getAll();
    final merged = <String, Transaction>{for (final transaction in cloudTransactions) transaction.id: transaction};
    for (final transaction in local) {
      final cloud = merged[transaction.id];
      if (cloud == null ||
          (transaction.updatedAt != null &&
              (cloud.updatedAt == null || transaction.updatedAt!.isAfter(cloud.updatedAt!)))) {
        merged[transaction.id] = transaction;
      }
    }
    final values = merged.values.toList();
    await _legacy.saveAll(values);
    return values;
  }

  @override
  Future<List<Transaction>> getTransactions() async {
    await _migrateOnce();
    return _legacy.getAll();
  }

  @override
  Stream<List<Transaction>> watchTransactions() async* {
    await _migrateOnce();
    yield await _legacy.getAll();
    await for (final cloudTransactions in _cloud.watchAll()) {
      yield await _mergeCloudSnapshot(cloudTransactions);
    }
  }

  @override
  Future<void> addTransaction(Transaction transaction) async {
    await _migrateOnce();
    await _upsertLocal(transaction);
    unawaited(_sync(() => _cloud.save(transaction)));
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    await _migrateOnce();
    await _upsertLocal(transaction);
    unawaited(_sync(() => _cloud.update(transaction)));
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _migrateOnce();
    final current = await _legacy.getAll();
    await _legacy.saveAll(current.where((transaction) => transaction.id != id).toList());
    unawaited(_sync(() => _cloud.delete(id)));
  }

  @override
  Future<void> deleteTransactionsForAccount(String accountId) async {
    await _migrateOnce();
    final current = await _legacy.getAll();
    await _legacy.saveAll(current.where((transaction) => transaction.accountId != accountId).toList());
    unawaited(_sync(() => _cloud.deleteForAccount(accountId)));
  }
}

