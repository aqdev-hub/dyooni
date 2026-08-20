import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/transactions/transactions_local_datasource.dart';
import '../../data/models/account.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/transactions/transactions_repository.dart';
import '../../data/repositories/transactions/transactions_repository_impl.dart';
import '../onboarding/onboarding_provider.dart' show sharedPreferencesProvider;

final transactionsLocalDataSourceProvider = Provider<TransactionsLocalDataSource>(
  (ref) => TransactionsLocalDataSource(ref.watch(sharedPreferencesProvider)),
);

final transactionsRepositoryProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepositoryImpl(ref.watch(transactionsLocalDataSourceProvider)),
);

final transactionsProvider = AsyncNotifierProvider<TransactionsController, List<Transaction>>(
  TransactionsController.new,
);

class TransactionsController extends AsyncNotifier<List<Transaction>> {
  @override
  Future<List<Transaction>> build() => ref.read(transactionsRepositoryProvider).getTransactions();

  Future<void> addTransaction(Transaction transaction) async {
    await ref.read(transactionsRepositoryProvider).addTransaction(transaction);
    state = AsyncData([...state.value ?? const [], transaction]);
  }

  Future<void> deleteForAccount(String accountId) async {
    await ref.read(transactionsRepositoryProvider).deleteTransactionsForAccount(accountId);
    state = AsyncData((state.value ?? const []).where((t) => t.accountId != accountId).toList());
  }
}

/// This account's transactions, oldest first — used by Account Details' history list.
final transactionsForAccountProvider = Provider.family.autoDispose<List<Transaction>, String>(
  (ref, accountId) {
    final all = ref.watch(transactionsProvider).value ?? const [];
    return all.where((t) => t.accountId == accountId).toList();
  },
);

/// Net balance for one account, derived from its transactions (credit adds, debit subtracts).
/// Assumes a single currency per account — a real multi-currency ledger would need per-currency
/// totals instead of one number; noted as a known simplification.
final accountBalanceProvider = Provider.family.autoDispose<double, String>((ref, accountId) {
  final transactions = ref.watch(transactionsForAccountProvider(accountId));
  var net = 0.0;
  for (final t in transactions) {
    net += t.direction == AccountDirection.credit ? t.amount : -t.amount;
  }
  return net;
});

/// The direction to display for an account's badge/amount color — credit if net >= 0, else debit.
final accountDirectionProvider = Provider.family.autoDispose<AccountDirection, String>((ref, accountId) {
  final net = ref.watch(accountBalanceProvider(accountId));
  return net >= 0 ? AccountDirection.credit : AccountDirection.debit;
});

final accountTransactionCountProvider = Provider.family.autoDispose<int, String>((ref, accountId) {
  return ref.watch(transactionsForAccountProvider(accountId)).length;
});
