import 'dart:async';

import '../../local/accounts/accounts_local_datasource.dart';
import '../../models/account.dart';
import '../../remote/firestore/accounts_firestore_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'accounts_repository.dart';

/// Local storage is the write-through source for the UI; Firestore synchronizes in the
/// background. This keeps account creation and edits usable while offline.
class AccountsFirestoreRepositoryImpl implements AccountsRepository {
  AccountsFirestoreRepositoryImpl(this._cloud, this._legacy, this._prefs, this._userId);
  final AccountsFirestoreDataSource _cloud;
  final AccountsLocalDataSource _legacy;
  final SharedPreferences _prefs;
  final String? _userId;
  bool _migrated = false;

  Future<void> _migrateOnce() async {
    final key = 'firestore_accounts_migrated_${_userId ?? 'anonymous'}';
    if (_migrated || _prefs.getBool(key) == true) return;
    final legacy = await _legacy.getAll();
    _migrated = true;
    await _prefs.setBool(key, true);
    for (final account in legacy) {
      unawaited(_sync(() => _cloud.save(account)));
    }
  }

  Future<void> _sync(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // Firestore persistence/reconnect will retry when available; the locally persisted data
      // remains authoritative for this device in the meantime.
    }
  }

  Future<void> _upsertLocal(Account account) async {
    final stamped = Account(
      id: account.id,
      name: account.name,
      category: account.category,
      createdDate: account.createdDate,
      details: account.details,
      phone: account.phone,
      ceiling: account.ceiling,
      attachmentPath: account.attachmentPath,
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

  /// A cloud snapshot can arrive before an offline local write reaches Firestore. Merge it with
  /// local data rather than replacing the list, so reconnecting never makes a just-saved account
  /// disappear from the UI.
  Future<List<Account>> _mergeCloudSnapshot(List<Account> cloudAccounts) async {
    final local = await _legacy.getAll();
    final merged = <String, Account>{for (final account in cloudAccounts) account.id: account};
    for (final account in local) {
      final cloud = merged[account.id];
      if (cloud == null || (account.updatedAt != null && (cloud.updatedAt == null || account.updatedAt!.isAfter(cloud.updatedAt!)))) {
        merged[account.id] = account;
      }
    }
    final values = merged.values.toList();
    await _legacy.saveAll(values);
    return values;
  }

  @override
  Future<List<Account>> getAccounts() async {
    await _migrateOnce();
    return _legacy.getAll();
  }

  @override
  Stream<List<Account>> watchAccounts() async* {
    await _migrateOnce();
    yield await _legacy.getAll();
    await for (final cloudAccounts in _cloud.watchAll()) {
      yield await _mergeCloudSnapshot(cloudAccounts);
    }
  }

  @override
  Future<void> addAccount(Account account) async {
    await _migrateOnce();
    await _upsertLocal(account);
    unawaited(_sync(() => _cloud.save(account)));
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _migrateOnce();
    final current = await _legacy.getAll();
    await _legacy.saveAll(current.where((account) => account.id != id).toList());
    unawaited(_sync(() => _cloud.delete(id)));
  }
}

