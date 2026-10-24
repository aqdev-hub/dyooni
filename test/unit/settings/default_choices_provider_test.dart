import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/category_type.dart';
import 'package:dyooni/data/models/transaction.dart';
import 'package:dyooni/data/repositories/accounts/accounts_repository.dart';
import 'package:dyooni/data/repositories/transactions/transactions_repository.dart';
import 'package:dyooni/logic/accounts/accounts_provider.dart';
import 'package:dyooni/logic/settings/default_choices_provider.dart';
import 'package:dyooni/logic/settings/general_settings_provider.dart';
import 'package:dyooni/logic/currencies/currencies_provider.dart';
import 'package:dyooni/logic/categories/categories_provider.dart';
import 'package:dyooni/logic/onboarding/onboarding_provider.dart' show sharedPreferencesProvider;
import 'package:dyooni/logic/transactions/transactions_provider.dart';

class MockAccountsRepository extends Mock implements AccountsRepository {
  // The controllers subscribe to watchAccounts() in build(); an unstubbed Mock returns null for
  // it and the whole provider fails. An empty stream = "no live updates", which is what tests want.
  @override
  Stream<List<Account>> watchAccounts() => const Stream.empty();
}

class MockTransactionsRepository extends Mock implements TransactionsRepository {
  @override
  Stream<List<Transaction>> watchTransactions() => const Stream.empty();
}

Account _account(String id, [AccountCategory category = AccountCategory.client]) =>
    Account(id: id, name: 'حساب $id', category: category, createdDate: DateTime(2026, 1, 1));

Future<ProviderContainer> _container({
  List<Transaction> transactions = const [],
  List<Account> accounts = const [],
  Map<String, Object> prefsValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  final txRepo = MockTransactionsRepository();
  final accountsRepo = MockAccountsRepository();
  when(() => txRepo.getTransactions()).thenAnswer((_) async => transactions);
  when(() => accountsRepo.getAccounts()).thenAnswer((_) async => accounts);

  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    transactionsRepositoryProvider.overrideWithValue(txRepo),
    accountsRepositoryProvider.overrideWithValue(accountsRepo),
  ]);
  addTearDown(container.dispose);
  await container.read(transactionsProvider.future);
  await container.read(accountsProvider.future);
  return container;
}

void main() {
  test('new account category: default beats last used beats Home tab', () async {
    final c = await _container();
    await c.read(generalSettingsProvider.future);
    final notifier = c.read(generalSettingsProvider.notifier);
    c.listen(newAccountCategoryProvider, (_, __) {});

    // Nothing chosen, nothing remembered → the app default (العملاء).
    expect(c.read(newAccountCategoryProvider), AccountCategory.client);

    await notifier.recordLastUsedCategory('supplier');
    expect(c.read(newAccountCategoryProvider), AccountCategory.supplier);

    await notifier.setDefaultCategory('client');
    expect(c.read(newAccountCategoryProvider), AccountCategory.client);
  });

  test('a default category that no longer exists falls back instead of breaking', () async {
    final c = await _container();
    await c.read(generalSettingsProvider.future);
    await c.read(generalSettingsProvider.notifier).setDefaultCategory('محذوف');
    expect(c.read(newAccountCategoryProvider), AccountCategory.client);
  });

  test('new entry currency: the chosen default, else the open currency page', () async {
    final c = await _container();
    await c.read(generalSettingsProvider.future);
    c.listen(newEntryCurrencyIdProvider, (_, __) {});
    expect(c.read(newEntryCurrencyIdProvider), 'LOCAL');

    await c.read(generalSettingsProvider.notifier).setDefaultCurrency('FOREIGN');
    expect(c.read(newEntryCurrencyIdProvider), 'FOREIGN');

    await c.read(generalSettingsProvider.notifier).setDefaultCurrency('محذوفة');
    expect(c.read(newEntryCurrencyIdProvider), 'LOCAL');
  });
}
