import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/currency_type.dart' show defaultCurrencyId;
import '../categories/categories_provider.dart';
import '../currencies/currencies_provider.dart';
import '../transactions/transactions_provider.dart';
import 'accounts_provider.dart';

/// What Home actually lists: the accounts of the SELECTED TAB (category) that also belong on the
/// SELECTED CURRENCY's page. Lives apart from accounts_provider.dart because it combines three
/// independent concerns (accounts, categories, currencies) and each of those files must stay
/// free of the others.
///
/// Category: "عام" (null) = every account; otherwise only that category's accounts.
/// Currency: an account is listed when it has at least one transaction in the selected currency.
/// An account with no transactions at all has no currency yet, so it is listed on the default
/// currency's page (otherwise a brand-new account would vanish until its first entry).
final currencyAccountsProvider = Provider.autoDispose<List<Account>>((ref) {
  final category = ref.watch(effectiveCategoryProvider);
  final accounts = [
    for (final a in ref.watch(accountsProvider).value ?? const <Account>[])
      if (category == null || a.category == category) a,
  ];
  final currency = ref.watch(effectiveCurrencyIdProvider);
  final all = ref.watch(transactionsProvider).value ?? const [];
  final hasAny = <String>{};
  final inCurrency = <String>{};
  for (final t in all) {
    hasAny.add(t.accountId);
    if (t.currency == currency) inCurrency.add(t.accountId);
  }
  return accounts
      .where((a) => inCurrency.contains(a.id) || (currency == defaultCurrencyId && !hasAny.contains(a.id)))
      .toList();
});

/// Totals of [currencyAccountsProvider] in the selected currency ONLY — the Home bottom bar. A
/// sum across currencies would be meaningless (500 USD + 500 YER is not 1000 of anything).
final currencyAccountsSummaryProvider = Provider.autoDispose<AccountsSummary>((ref) {
  final accounts = ref.watch(currencyAccountsProvider);
  final currency = ref.watch(effectiveCurrencyIdProvider);
  var credit = 0.0;
  var debit = 0.0;
  for (final account in accounts) {
    final balance = ref.watch(accountCurrencyBalanceProvider((accountId: account.id, currency: currency)));
    if (balance >= 0) {
      credit += balance;
    } else {
      debit += -balance;
    }
  }
  return AccountsSummary(totalCredit: credit, totalDebit: debit, count: accounts.length);
});
