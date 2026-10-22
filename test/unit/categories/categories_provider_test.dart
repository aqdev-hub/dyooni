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
import 'package:dyooni/logic/categories/categories_provider.dart';
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
  test('a fresh install has عام / العملاء / الموردين, all visible', () async {
    final c = await _container();
    final list = c.read(categoryTypesProvider);
    expect(list.map((e) => e.name), ['عام', 'العملاء', 'الموردين']);
    expect(list.every((e) => e.visible), isTrue);
    expect(c.read(categoryTabsProvider), [null, AccountCategory.client, AccountCategory.supplier]);
  });

  test('add: appears everywhere, persists, refuses blank and duplicate names', () async {
    final c = await _container();
    final store = c.read(categoryTypesStoreProvider.notifier);
    await store.add('  شركاء  ');
    expect(c.read(assignableCategoriesProvider).map((e) => e.name), contains('شركاء'));
    expect(c.read(categoryTabsProvider).map((e) => e?.id), contains('شركاء'));
    expect(store.validateName(''), CategoryNameError.empty);
    expect(store.validateName('شركاء'), CategoryNameError.duplicate);
    expect(() => store.add('العملاء'), throwsA(isA<CategoryNameException>()));
    // A second container over the same prefs still sees it.
    final prefs = c.read(sharedPreferencesProvider);
    final c2 = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      accountsRepositoryProvider.overrideWithValue(MockAccountsRepository()),
      transactionsRepositoryProvider.overrideWithValue(MockTransactionsRepository()),
    ]);
    addTearDown(c2.dispose);
    expect(c2.read(categoryTypesStoreProvider).map((e) => e.name), contains('شركاء'));
  });

  test('rename keeps the id, so existing accounts follow the new name', () async {
    final c = await _container(accounts: [_account('1')]);
    await c.read(categoryTypesStoreProvider.notifier).rename('client', 'زبائن');
    expect(categoryNameOf(c.read(categoryTypesProvider), 'client'), 'زبائن');
    expect(c.read(accountsProvider).value!.single.category, AccountCategory.client);
  });

  test('usage: عام counts every account, others count their own', () async {
    final c = await _container(accounts: [_account('1'), _account('2'), _account('3', AccountCategory.supplier)]);
    final usage = c.read(categoryUsageProvider);
    expect(usage[generalCategoryId], 3);
    expect(usage['client'], 2);
    expect(usage['supplier'], 1);
  });

  test('setVisible hides a tab, but never the last visible one', () async {
    final c = await _container();
    final store = c.read(categoryTypesStoreProvider.notifier);
    await store.setVisible('client', false);
    expect(c.read(categoryTabsProvider), [null, AccountCategory.supplier]);
    await store.setVisible(generalCategoryId, false);
    expect(c.read(categoryTabsProvider), [AccountCategory.supplier]);
    expect(() => store.setVisible('supplier', false), throwsA(isA<CategoryVisibilityException>()));
  });

  test('delete rules: general protected, in-use blocked, empty one removed', () async {
    final c = await _container(accounts: [_account('1')]);
    final store = c.read(categoryTypesStoreProvider.notifier);
    await expectLater(
      store.delete(generalCategoryId),
      throwsA(isA<CategoryDeleteException>().having((e) => e.reason, 'reason', CategoryDeleteBlock.protected)),
    );
    await expectLater(
      store.delete('client'),
      throwsA(isA<CategoryDeleteException>().having((e) => e.reason, 'reason', CategoryDeleteBlock.inUse)),
    );
    await store.delete('supplier');
    expect(c.read(categoryTypesProvider).map((e) => e.id), ['general', 'client']);
    await store.setVisible('client', true);
  });

  test('the last real category cannot be deleted', () async {
    final c = await _container();
    final store = c.read(categoryTypesStoreProvider.notifier);
    await store.delete('supplier');
    await expectLater(
      store.delete('client'),
      throwsA(isA<CategoryDeleteException>().having((e) => e.reason, 'reason', CategoryDeleteBlock.lastOne)),
    );
  });

  test('a category used by an account but missing from the list is still offered', () async {
    final c = await _container(accounts: [_account('1', const AccountCategory('قديم'))]);
    expect(c.read(assignableCategoriesProvider).map((e) => e.id), contains('قديم'));
  });

  test('Home falls back to the first visible tab when the selected one is hidden', () async {
    final c = await _container();
    c.listen(effectiveCategoryProvider, (_, __) {});
    c.read(selectedCategoryProvider.notifier).state = AccountCategory.supplier;
    expect(c.read(effectiveCategoryProvider), AccountCategory.supplier);
    await c.read(categoryTypesStoreProvider.notifier).setVisible('supplier', false);
    expect(c.read(effectiveCategoryProvider), isNull); // عام
  });
}
