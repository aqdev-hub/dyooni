import '../../local/accounts/accounts_local_datasource.dart';
import '../../models/account.dart';
import '../../remote/firestore/accounts_firestore_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'accounts_repository.dart';

/// Firestore is the live source of truth. The local source is retained only to
/// upload pre-Firestore records once, never as a parallel sync system.
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
    for (final account in legacy) {
      await _cloud.save(account);
    }
    _migrated = true;
    await _prefs.setBool(key, true);
  }

  @override
  Future<List<Account>> getAccounts() async {
    await _migrateOnce();
    return _cloud.getAll();
  }

  @override
  Stream<List<Account>> watchAccounts() async* {
    await _migrateOnce();
    yield* _cloud.watchAll();
  }

  @override
  Future<void> addAccount(Account account) async {
    await _migrateOnce();
    await _cloud.save(account);
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _migrateOnce();
    await _cloud.delete(id);
  }
}
