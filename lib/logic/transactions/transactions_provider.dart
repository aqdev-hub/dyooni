import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/local/transactions/transactions_local_datasource.dart';
import '../../data/models/account.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/transactions/transactions_repository.dart';
import '../../data/repositories/transactions/transactions_firestore_repository_impl.dart';
import '../../data/remote/firestore/transactions_firestore_datasource.dart';
import '../onboarding/onboarding_provider.dart' show sharedPreferencesProvider;

final transactionsLocalDataSourceProvider = Provider<TransactionsLocalDataSource>(
  (ref) => TransactionsLocalDataSource(ref.watch(sharedPreferencesProvider)),
);

final transactionsRepositoryProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsFirestoreRepositoryImpl(
    TransactionsFirestoreDataSource(FirebaseFirestore.instance, FirebaseAuth.instance),
    ref.watch(transactionsLocalDataSourceProvider),
    ref.watch(sharedPreferencesProvider),
    FirebaseAuth.instance.currentUser?.uid,
  ),
);

final transactionsProvider = AsyncNotifierProvider<TransactionsController, List<Transaction>>(
  TransactionsController.new,
);

class TransactionsController extends AsyncNotifier<List<Transaction>> {
  StreamSubscription<List<Transaction>>? _subscription;

  @override
  Future<List<Transaction>> build() async {
    final repository = ref.read(transactionsRepositoryProvider);
    final initial = await repository.getTransactions();
    _subscription = repository.watchTransactions().listen(
      (transactions) => state = AsyncData(transactions),
      onError: (Object error, StackTrace stackTrace) => state = AsyncError(error, stackTrace),
    );
    ref.onDispose(() => _subscription?.cancel());
    return initial;
  }

  Future<void> addTransaction(Transaction transaction) async {
    await ref.read(transactionsRepositoryProvider).addTransaction(transaction);
    state = AsyncData([...state.value ?? const <Transaction>[], transaction]);
  }

  /// Persists an edit to an existing transaction (same id) — used by the new "tap a transaction
  /// row to edit it" flow on Account Details.
  Future<void> updateTransaction(Transaction transaction) async {
    await ref.read(transactionsRepositoryProvider).updateTransaction(transaction);
    state = AsyncData([
      for (final t in state.value ?? const <Transaction>[])
        if (t.id == transaction.id) transaction else t,
    ]);
  }

  /// Deletes exactly one transaction — used by the edit screen's "حذف" button and by the
  /// long-press action sheet's "حذف"/multi-select delete.
  Future<void> deleteTransaction(String id) async {
    await ref.read(transactionsRepositoryProvider).deleteTransaction(id);
    state = AsyncData((state.value ?? const <Transaction>[]).where((t) => t.id != id).toList());
  }

  Future<void> deleteForAccount(String accountId) async {
    await ref.read(transactionsRepositoryProvider).deleteTransactionsForAccount(accountId);
    state = AsyncData((state.value ?? const <Transaction>[]).where((t) => t.accountId != accountId).toList());
  }
}

/// This account's transactions, oldest first — used by Account Details' history list.
final transactionsForAccountProvider = Provider.family.autoDispose<List<Transaction>, String>(
  (ref, accountId) {
    final all = ref.watch(transactionsProvider).value ?? const <Transaction>[];
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

/// Multi-select state for the Account Details transaction table's long-press "تحديد"/"تحديد الكل"
/// flow (see EntityAction in view/widgets/shared/entity_actions_sheet.dart). `.autoDispose` since
/// a selection only makes sense for the lifetime of that screen being on top.
final transactionSelectionModeProvider = StateProvider.autoDispose<bool>((ref) => false);

/// The set of currently-selected transaction ids while [transactionSelectionModeProvider] is true.
final selectedTransactionIdsProvider = StateProvider.autoDispose<Set<String>>((ref) => <String>{});
