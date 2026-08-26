import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/local/accounts/accounts_local_datasource.dart';
import '../../data/models/account.dart';
import '../../data/repositories/accounts/accounts_repository.dart';
import '../../data/repositories/accounts/accounts_firestore_repository_impl.dart';
import '../../data/remote/firestore/accounts_firestore_datasource.dart';
import '../onboarding/onboarding_provider.dart' show sharedPreferencesProvider;
import '../transactions/transactions_provider.dart';

final accountsLocalDataSourceProvider = Provider<AccountsLocalDataSource>(
  (ref) => AccountsLocalDataSource(ref.watch(sharedPreferencesProvider)),
);

final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => AccountsFirestoreRepositoryImpl(
    AccountsFirestoreDataSource(FirebaseFirestore.instance, FirebaseAuth.instance),
    ref.watch(accountsLocalDataSourceProvider),
    ref.watch(sharedPreferencesProvider),
    FirebaseAuth.instance.currentUser?.uid,
  ),
);

final accountsProvider = AsyncNotifierProvider<AccountsController, List<Account>>(
  AccountsController.new,
);

class AccountsController extends AsyncNotifier<List<Account>> {
  StreamSubscription<List<Account>>? _subscription;

  @override
  Future<List<Account>> build() async {
    final repository = ref.read(accountsRepositoryProvider);
    final initial = await repository.getAccounts();
    _subscription = repository.watchAccounts().listen(
      (accounts) => state = AsyncData(accounts),
      onError: (Object error, StackTrace stackTrace) => state = AsyncError(error, stackTrace),
    );
    ref.onDispose(() => _subscription?.cancel());
    return initial;
  }

  Future<void> addAccount(Account account) async {
    await ref.read(accountsRepositoryProvider).addAccount(account);
    state = AsyncData([...state.value ?? const <Account>[], account]);
  }

  /// Persists an edit to an EXISTING account (same id) — used by the new "تعديل" flow (3-dot
  /// menu on Account Details, and the long-press action sheet / selection toolbar on Home).
  /// [AccountsRepository.addAccount] already writes via `.doc(id).set(...)` under the hood, which
  /// is an upsert, so the same repository call works for both create and update — the only real
  /// difference is how the LOCAL state list is reconciled afterwards: [addAccount] above always
  /// appends, which would wrongly duplicate an existing entry if it were reused here.
  Future<void> updateAccount(Account account) async {
    await ref.read(accountsRepositoryProvider).addAccount(account);
    state = AsyncData([
      for (final a in state.value ?? const <Account>[])
        if (a.id == account.id) account else a,
    ]);
  }

  /// Deletes the account AND every transaction that belongs to it — an orphaned transaction
  /// pointing at a deleted account would silently corrupt every derived total.
  Future<void> deleteAccount(String id) async {
    await ref.read(accountsRepositoryProvider).deleteAccount(id);
    await ref.read(transactionsProvider.notifier).deleteForAccount(id);
    state = AsyncData((state.value ?? const <Account>[]).where((a) => a.id != id).toList());
  }
}

/// `null` = the "عام" (all) tab. Home screen sets this from the selected TabController index.
final selectedCategoryProvider = StateProvider.autoDispose<AccountCategory?>((ref) => null);

/// Accounts filtered by [selectedCategoryProvider] — what the list view actually renders.
final filteredAccountsProvider = Provider.autoDispose<List<Account>>((ref) {
  final accounts = ref.watch(accountsProvider).value ?? const [];
  final category = ref.watch(selectedCategoryProvider);
  if (category == null) return accounts;
  return accounts.where((a) => a.category == category).toList();
});

/// Derived totals for the summary card, scoped to the currently selected tab/category, computed
/// from each account's transactions (see transactions_provider.dart) — never from a stored
/// amount, since accounts no longer store one.
class AccountsSummary {
  const AccountsSummary({required this.totalCredit, required this.totalDebit, required this.count});
  final double totalCredit;
  final double totalDebit;
  final int count;
  double get net => totalCredit - totalDebit;
}

final accountsSummaryProvider = Provider.autoDispose<AccountsSummary>((ref) {
  return _summarize(ref, ref.watch(filteredAccountsProvider));
});

/// Same computation as [accountsSummaryProvider] but deliberately independent of
/// [selectedCategoryProvider] — the Reports screen must show the true overall totals regardless
/// of whatever tab was last left selected on Home; it is a separate screen, not a mirror of it.
final overallSummaryProvider = Provider.autoDispose<AccountsSummary>((ref) {
  return _summarize(ref, ref.watch(accountsProvider).value ?? const []);
});

AccountsSummary _summarize(Ref ref, List<Account> accounts) {
  var credit = 0.0;
  var debit = 0.0;
  for (final account in accounts) {
    final balance = ref.watch(accountBalanceProvider(account.id));
    if (balance >= 0) {
      credit += balance;
    } else {
      debit += -balance;
    }
  }
  return AccountsSummary(totalCredit: credit, totalDebit: debit, count: accounts.length);
}

/// Multi-select state for the Home account list's long-press "تحديد"/"تحديد الكل" flow (see
/// EntityAction in view/widgets/shared/entity_actions_sheet.dart). Deliberately NOT persisted and
/// `.autoDispose` — a selection only ever makes sense for the lifetime of Home being on screen.
final accountSelectionModeProvider = StateProvider.autoDispose<bool>((ref) => false);

/// The set of currently-selected account ids while [accountSelectionModeProvider] is true.
final selectedAccountIdsProvider = StateProvider.autoDispose<Set<String>>((ref) => <String>{});
