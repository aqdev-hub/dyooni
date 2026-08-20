import '../../local/transactions/transactions_local_datasource.dart';
import '../../models/transaction.dart';
import 'transactions_repository.dart';

class TransactionsRepositoryImpl implements TransactionsRepository {
  const TransactionsRepositoryImpl(this._local);
  final TransactionsLocalDataSource _local;

  @override
  Future<List<Transaction>> getTransactions() => _local.getAll();

  @override
  Future<void> addTransaction(Transaction transaction) async {
    final current = await _local.getAll();
    await _local.saveAll([...current, transaction]);
  }

  @override
  Future<void> deleteTransactionsForAccount(String accountId) async {
    final current = await _local.getAll();
    await _local.saveAll(current.where((t) => t.accountId != accountId).toList());
  }
}
