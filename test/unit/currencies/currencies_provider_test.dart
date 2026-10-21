import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/currency_type.dart';
import 'package:dyooni/data/models/transaction.dart';
import 'package:dyooni/data/repositories/accounts/accounts_repository.dart';
import 'package:dyooni/data/repositories/transactions/transactions_repository.dart';
import 'package:dyooni/logic/accounts/accounts_provider.dart';
import 'package:dyooni/logic/currencies/currencies_provider.dart';
import 'package:dyooni/logic/onboarding/onboarding_provider.dart' show sharedPreferencesProvider;
import 'package:dyooni/logic/transactions/transactions_provider.dart';

class MockAccountsRepository extends Mock implements AccountsRepository {}

class MockTransactionsRepository extends Mock implements TransactionsRepository {}

Transaction _tx(String id, String accountId, double amount, String currency, AccountDirection direction) => Transaction(
      id: id,
      accountId: accountId,
      amount: amount,
      currency: currency,
      direction: direction,
      date: DateTime(2026, 1, 1),
    );

Account _account(String id) =>
    Account(id: id, name: 'حساب $id', category: AccountCategory.client, createdDate: DateTime(2026, 1, 1));

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
  group('currency list', () {
    test('a fresh install starts with exactly محلي and أجنبي', () async {
      final container = await _container();

      expect(container.read(currencyTypesProvider), defaultCurrencyTypes);
    });

    test('currencies used by old transactions appear with their legacy names', () async {
      final container = await _container(
        transactions: [_tx('t1', 'a1', 100, 'USD', AccountDirection.credit)],
      );

      final names = {for (final c in container.read(currencyTypesProvider)) c.id: c.name};
      expect(names['USD'], 'دولار أمريكي');
      expect(names['LOCAL'], 'محلي');
    });

    test('add() saves the currency and it survives a reload', () async {
      final container = await _container();

      final created = await container.read(currencyTypesStoreProvider.notifier).add('  ريال سعودي ');

      expect(created.name, 'ريال سعودي');
      expect(container.read(currencyTypesProvider).map((c) => c.name), contains('ريال سعودي'));

      final prefs = container.read(sharedPreferencesProvider);
      final reloaded = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        transactionsRepositoryProvider.overrideWithValue(MockTransactionsRepository()),
      ]);
      addTearDown(reloaded.dispose);
      expect(reloaded.read(currencyTypesStoreProvider).map((c) => c.name), contains('ريال سعودي'));
    });

    test('empty and duplicate names are refused', () async {
      final container = await _container();
      final store = container.read(currencyTypesStoreProvider.notifier);

      await expectLater(store.add('   '), throwsA(isA<CurrencyNameException>()));
      await expectLater(store.add('محلي'), throwsA(isA<CurrencyNameException>()));
      expect(store.validateName('محلي'), CurrencyNameError.duplicate);
      expect(store.validateName(''), CurrencyNameError.empty);
      expect(store.validateName('ين ياباني'), isNull);
    });

    test('renaming keeps the id, and a new currency never reuses an old id', () async {
      final container = await _container();
      final store = container.read(currencyTypesStoreProvider.notifier);

      final dollar = await store.add('دولار');
      await store.rename(dollar.id, 'دولار أمريكي');
      final second = await store.add('دولار');

      final list = container.read(currencyTypesProvider);
      expect(list.firstWhere((c) => c.id == dollar.id).name, 'دولار أمريكي');
      expect(second.id, isNot(dollar.id));
    });

    test('the default currency and any currency with transactions cannot be deleted', () async {
      final container = await _container(
        transactions: [_tx('t1', 'a1', 100, 'FOREIGN', AccountDirection.credit)],
      );
      final store = container.read(currencyTypesStoreProvider.notifier);

      await expectLater(store.delete(defaultCurrencyId), throwsA(isA<CurrencyDeleteException>()));
      await expectLater(store.delete('FOREIGN'), throwsA(isA<CurrencyDeleteException>()));

      final unused = await store.add('جنيه');
      await store.delete(unused.id);
      expect(container.read(currencyTypesProvider).any((c) => c.id == unused.id), isFalse);
    });
  });

  group('separation by currency', () {
    final txs = [
      _tx('t1', 'a1', 500, 'LOCAL', AccountDirection.credit),
      _tx('t2', 'a1', 100, 'LOCAL', AccountDirection.debit),
      _tx('t3', 'a1', 40, 'FOREIGN', AccountDirection.credit),
      _tx('t4', 'a2', 70, 'FOREIGN', AccountDirection.debit),
    ];

    test("one account's transactions and balance are kept per currency", () async {
      final container = await _container(transactions: txs, accounts: [_account('a1'), _account('a2')]);

      const local = (accountId: 'a1', currency: 'LOCAL');
      const foreign = (accountId: 'a1', currency: 'FOREIGN');
      expect(container.read(accountCurrencyTransactionsProvider(local)).map((t) => t.id), ['t1', 't2']);
      expect(container.read(accountCurrencyBalanceProvider(local)), 400);
      expect(container.read(accountCurrencyBalanceProvider(foreign)), 40);
      expect(container.read(accountCurrencyCountsProvider('a1')), {'LOCAL': 2, 'FOREIGN': 1});
    });

    test('Home lists each account only on the pages of the currencies it has', () async {
      final container = await _container(
        transactions: txs,
        accounts: [_account('a1'), _account('a2'), _account('a3')],
      );

      // محلي page: a1 (has LOCAL) and a3 (no transactions at all); NOT a2 (foreign only).
      expect(container.read(currencyAccountsProvider).map((a) => a.id), ['a1', 'a3']);
      final localSummary = container.read(currencyAccountsSummaryProvider);
      expect(localSummary.totalCredit, 400);
      expect(localSummary.totalDebit, 0);

      container.read(selectedCurrencyIdProvider.notifier).state = 'FOREIGN';
      expect(container.read(currencyAccountsProvider).map((a) => a.id), ['a1', 'a2']);
      final foreignSummary = container.read(currencyAccountsSummaryProvider);
      expect(foreignSummary.totalCredit, 40);
      expect(foreignSummary.totalDebit, 70);
    });

    test('a selected currency that no longer exists falls back to the default', () async {
      final container = await _container();

      container.read(selectedCurrencyIdProvider.notifier).state = 'GONE';

      expect(container.read(effectiveCurrencyIdProvider), defaultCurrencyId);
    });
  });
}
