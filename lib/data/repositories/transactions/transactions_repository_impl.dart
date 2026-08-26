import '../../local/transactions/transactions_local_datasource.dart';
import '../../models/transaction.dart';
import 'transactions_repository.dart';

class TransactionsRepositoryImpl implements TransactionsRepository {
  const TransactionsRepositoryImpl(this._local);
  final TransactionsLocalDataSource _local;

  @override
  Future<List<Transaction>> getTransactions() => _local.getAll();

  @override
  Stream<List<Transaction>> watchTransactions() async* {
    yield await getTransactions();
  }

  @override
  Future<void> addTransaction(Transaction transaction) async {
    final current = await _local.getAll();
    await _local.saveAll([...current, transaction]);
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    final current = await _local.getAll();
    final updated = [for (final t in current) if (t.id == transaction.id) transaction else t];
    await _local.saveAll(updated);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final current = await _local.getAll();
    await _local.saveAll(current.where((t) => t.id != id).toList());
  }

  @override
  Future<void> deleteTransactionsForAccount(String accountId) async {
    final current = await _local.getAll();
    await _local.saveAll(current.where((t) => t.accountId != accountId).toList());
  }
}
