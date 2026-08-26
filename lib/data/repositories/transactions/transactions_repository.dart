import '../../models/transaction.dart';

/// `logic/` imports this interface only — never the DataSource directly (see repository-di.md).
abstract class TransactionsRepository {
  Future<List<Transaction>> getTransactions();
  Stream<List<Transaction>> watchTransactions();
  Future<void> addTransaction(Transaction transaction);

  /// Updates one existing transaction in place (same id). Added alongside [deleteTransaction] so
  /// a single entry can be edited from the account-details screen instead of only ever being
  /// added or bulk-deleted-by-account.
  Future<void> updateTransaction(Transaction transaction);

  /// Deletes exactly one transaction by id — distinct from [deleteTransactionsForAccount], which
  /// removes every entry for a whole account (used only when the account itself is deleted).
  Future<void> deleteTransaction(String id);

  Future<void> deleteTransactionsForAccount(String accountId);
}
