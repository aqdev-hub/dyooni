import '../../models/transaction.dart';

/// `logic/` imports this interface only — never the DataSource directly (see repository-di.md).
abstract class TransactionsRepository {
  Future<List<Transaction>> getTransactions();
  Future<void> addTransaction(Transaction transaction);
  Future<void> deleteTransactionsForAccount(String accountId);
}
