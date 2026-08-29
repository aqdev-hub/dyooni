import '../../../core/utils/app_exception.dart';
import '../../models/backup_snapshot.dart';
import '../accounts/accounts_repository.dart';
import '../settings/personal_data_repository.dart';
import '../transactions/transactions_repository.dart';
import 'backup_repository.dart';

class BackupRepositoryImpl implements BackupRepository {
  const BackupRepositoryImpl(this._accounts, this._transactions, this._personalData);
  final AccountsRepository _accounts;
  final TransactionsRepository _transactions;
  final PersonalDataRepository _personalData;

  @override
  Future<BackupSnapshot> buildSnapshot() async {
    try {
      final accounts = await _accounts.getAccounts();
      final transactions = await _transactions.getTransactions();
      final personalData = await _personalData.getPersonalData();
      return BackupSnapshot(
        schemaVersion: BackupSnapshot.currentSchemaVersion,
        createdAt: DateTime.now(),
        accounts: accounts,
        transactions: transactions,
        personalData: personalData,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnexpectedException(internalDetail: e.toString());
    }
  }

  @override
  Future<void> restoreSnapshot(BackupSnapshot snapshot) async {
    if (snapshot.schemaVersion > BackupSnapshot.currentSchemaVersion) {
      throw const ValidationException('backupIncompatible');
    }
    try {
      // Sequential, not Future.wait: accounts are written before their transactions on purpose,
      // matching the order they're created in normally (add_account_screen.dart creates the
      // account, then its first transaction) — never strictly required since both writes are
      // upserts by id, but keeps this path's behavior easy to reason about for large backups.
      for (final account in snapshot.accounts) {
        await _accounts.addAccount(account); // upsert by id — see accounts_firestore_datasource.dart
      }
      for (final transaction in snapshot.transactions) {
        await _transactions.addTransaction(transaction); // also an upsert by id
      }
      await _personalData.savePersonalData(snapshot.personalData);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnexpectedException(internalDetail: e.toString());
    }
  }
}
