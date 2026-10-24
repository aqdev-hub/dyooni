import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/currencies/currencies_local_datasource.dart';
import '../../data/models/account.dart' show AccountDirection;
import '../../data/models/currency_type.dart';
import '../../data/models/transaction.dart';
import '../onboarding/onboarding_provider.dart' show sharedPreferencesProvider;
import '../transactions/transactions_provider.dart';

final currenciesLocalDataSourceProvider = Provider<CurrenciesLocalDataSource>(
  (ref) => CurrenciesLocalDataSource(ref.watch(sharedPreferencesProvider)),
);

/// Why a currency name was refused. Mapped to localized text in the view.
enum CurrencyNameError { empty, duplicate }

class CurrencyNameException implements Exception {
  const CurrencyNameException(this.error);
  final CurrencyNameError error;
}

/// Why a currency cannot be deleted. Mapped to localized text in the view.
enum CurrencyDeleteBlock {
  /// The built-in default currency.
  protected,

  /// At least one transaction is recorded in it — deleting it would orphan that money.
  inUse,
}

class CurrencyDeleteException implements Exception {
  const CurrencyDeleteException(this.reason);
  final CurrencyDeleteBlock reason;
}

/// What the person has explicitly saved (or the two defaults). Do NOT read this from screens —
/// read [currencyTypesProvider], which also includes currencies that old transactions use.
final currencyTypesStoreProvider = NotifierProvider<CurrencyTypesStore, List<CurrencyType>>(
  CurrencyTypesStore.new,
);

class CurrencyTypesStore extends Notifier<List<CurrencyType>> {
  @override
  List<CurrencyType> build() {
    final saved = ref.watch(currenciesLocalDataSourceProvider).get();
    if (saved == null || saved.isEmpty) return defaultCurrencyTypes;
    // The default currency is guaranteed to exist even if the stored list was damaged.
    if (!saved.any((c) => c.id == defaultCurrencyId)) return [defaultCurrencyTypes.first, ...saved];
    return saved;
  }

  static String _normalize(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// `null` when [raw] is acceptable. [excludeId] is the currency being renamed (it may keep its
  /// own name).
  CurrencyNameError? validateName(String raw, {String? excludeId}) {
    final name = _normalize(raw);
    if (name.isEmpty) return CurrencyNameError.empty;
    final taken = ref.read(currencyTypesProvider).any((c) => c.id != excludeId && _normalize(c.name) == name);
    return taken ? CurrencyNameError.duplicate : null;
  }

  /// Ids are never reused: a renamed currency keeps its old id, so a NEW currency that happens to
  /// get the old name must not take that id or the two would merge.
  String _uniqueId(String name, Iterable<String> takenIds) {
    final taken = takenIds.toSet();
    final base = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (!taken.contains(base)) return base;
    var n = 2;
    while (taken.contains('$base $n')) {
      n++;
    }
    return '$base $n';
  }

  Future<void> _persist(List<CurrencyType> next) async {
    await ref.read(currenciesLocalDataSourceProvider).save(next);
    state = next;
  }

  /// Saves the FULL merged list (stored + the ones old transactions use), so a currency that only
  /// existed implicitly becomes an explicit, editable entry the first time anything is changed.
  Future<CurrencyType> add(String rawName) async {
    final error = validateName(rawName);
    if (error != null) throw CurrencyNameException(error);
    final current = ref.read(currencyTypesProvider);
    final created = CurrencyType(id: _uniqueId(rawName, current.map((c) => c.id)), name: rawName.trim());
    await _persist([...current, created]);
    return created;
  }

  Future<void> rename(String id, String rawName) async {
    final error = validateName(rawName, excludeId: id);
    if (error != null) throw CurrencyNameException(error);
    final current = ref.read(currencyTypesProvider);
    await _persist([
      for (final c in current)
        if (c.id == id) c.copyWith(name: rawName.trim()) else c,
    ]);
  }

  Future<void> delete(String id) async {
    if (id == defaultCurrencyId) throw const CurrencyDeleteException(CurrencyDeleteBlock.protected);
    if ((ref.read(currencyUsageProvider)[id] ?? 0) > 0) {
      throw const CurrencyDeleteException(CurrencyDeleteBlock.inUse);
    }
    final current = ref.read(currencyTypesProvider);
    await _persist([for (final c in current) if (c.id != id) c]);
  }
}

/// EVERY currency that exists for display and entry: the person's list, plus any currency a
/// transaction already uses that is missing from it (data from before this feature, or restored
/// from another device). Nothing recorded can therefore ever fall out of the lists.
final currencyTypesProvider = Provider<List<CurrencyType>>((ref) {
  final stored = ref.watch(currencyTypesStoreProvider);
  final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
  final known = {for (final c in stored) c.id};
  final extra = <CurrencyType>[];
  for (final t in transactions) {
    if (known.add(t.currency)) {
      extra.add(CurrencyType(id: t.currency, name: legacyCurrencyName(t.currency) ?? t.currency));
    }
  }
  return extra.isEmpty ? stored : [...stored, ...extra];
});

/// How many transactions (across all accounts) are recorded in each currency id.
final currencyUsageProvider = Provider<Map<String, int>>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
  final counts = <String, int>{};
  for (final t in transactions) {
    counts[t.currency] = (counts[t.currency] ?? 0) + 1;
  }
  return counts;
});

/// The currency "page" the person is looking at. ONE value for the whole app: Home lists the
/// accounts of this currency and Account Details shows an account's transactions in it, so the
/// two always agree.
final selectedCurrencyIdProvider = StateProvider<String>((ref) => defaultCurrencyId);

/// [selectedCurrencyIdProvider], falling back to the default when the selected currency no
/// longer exists (deleted, or a different account/backup was loaded).
final effectiveCurrencyIdProvider = Provider<String>((ref) {
  final selected = ref.watch(selectedCurrencyIdProvider);
  final exists = ref.watch(currencyTypesProvider).any((c) => c.id == selected);
  return exists ? selected : defaultCurrencyId;
});

/// Key for the per-account, per-currency providers below.
typedef AccountCurrencyKey = ({String accountId, String currency});

/// One account's transactions in ONE currency — what Account Details shows.
final accountCurrencyTransactionsProvider =
    Provider.family.autoDispose<List<Transaction>, AccountCurrencyKey>((ref, key) {
  return ref.watch(transactionsForAccountProvider(key.accountId)).where((t) => t.currency == key.currency).toList();
});

/// Net balance of one account in ONE currency (credit adds, debit subtracts).
final accountCurrencyBalanceProvider = Provider.family.autoDispose<double, AccountCurrencyKey>((ref, key) {
  var net = 0.0;
  for (final t in ref.watch(accountCurrencyTransactionsProvider(key))) {
    net += t.direction == AccountDirection.credit ? t.amount : -t.amount;
  }
  return net;
});

/// How many transactions one account has in each currency id (only currencies it uses appear) —
/// drives the dollar-icon switcher on Account Details.
final accountCurrencyCountsProvider = Provider.family.autoDispose<Map<String, int>, String>((ref, accountId) {
  final counts = <String, int>{};
  for (final t in ref.watch(transactionsForAccountProvider(accountId))) {
    counts[t.currency] = (counts[t.currency] ?? 0) + 1;
  }
  return counts;
});
