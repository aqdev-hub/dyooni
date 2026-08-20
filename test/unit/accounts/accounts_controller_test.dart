import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/transaction.dart';
import 'package:dyooni/data/repositories/accounts/accounts_repository.dart';
import 'package:dyooni/data/repositories/transactions/transactions_repository.dart';
import 'package:dyooni/logic/accounts/accounts_provider.dart';
import 'package:dyooni/logic/transactions/transactions_provider.dart';

class MockAccountsRepository extends Mock implements AccountsRepository {}

class MockTransactionsRepository extends Mock implements TransactionsRepository {}

void main() {
  late MockAccountsRepository accountsRepo;
  late MockTransactionsRepository transactionsRepo;
  late ProviderContainer container;

  final client = Account(
    id: 'a1',
    name: 'أحمد محمد',
    category: AccountCategory.client,
    createdDate: DateTime(2026, 1, 1),
  );
  final supplier = Account(
    id: 'a2',
    name: 'سالم علي',
    category: AccountCategory.supplier,
    createdDate: DateTime(2026, 1, 2),
  );

  setUp(() {
    accountsRepo = MockAccountsRepository();
    transactionsRepo = MockTransactionsRepository();
    container = ProviderContainer(
      overrides: [
        accountsRepositoryProvider.overrideWithValue(accountsRepo),
        transactionsRepositoryProvider.overrideWithValue(transactionsRepo),
      ],
    );
    addTearDown(container.dispose);
    when(() => transactionsRepo.getTransactions()).thenAnswer((_) async => []);
  });

  test('build() loads the initial account list from the repository', () async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => [client]);

    final result = await container.read(accountsProvider.future);

    expect(result, [client]);
  });

  test('addAccount() persists via the repository and appends to state', () async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => []);
    when(() => accountsRepo.addAccount(any())).thenAnswer((_) async {});

    await container.read(accountsProvider.future);
    await container.read(accountsProvider.notifier).addAccount(client);

    verify(() => accountsRepo.addAccount(client)).called(1);
    expect(container.read(accountsProvider).value, [client]);
  });

  test('deleteAccount() removes the account AND cascades to its transactions', () async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => [client]);
    when(() => accountsRepo.deleteAccount('a1')).thenAnswer((_) async {});
    when(() => transactionsRepo.deleteTransactionsForAccount('a1')).thenAnswer((_) async {});
    await container.read(accountsProvider.future);
    await container.read(transactionsProvider.future);

    await container.read(accountsProvider.notifier).deleteAccount('a1');

    verify(() => accountsRepo.deleteAccount('a1')).called(1);
    verify(() => transactionsRepo.deleteTransactionsForAccount('a1')).called(1);
    expect(container.read(accountsProvider).value, isEmpty);
  });

  test('summary provider derives totals from each account\'s transactions, not a stored amount',
      () async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => [client, supplier]);
    when(() => transactionsRepo.getTransactions()).thenAnswer(
      (_) async => [
        Transaction(id: 't1', accountId: 'a1', amount: 500, currency: 'SAR', direction: AccountDirection.credit, date: DateTime(2026, 1, 1)),
        Transaction(id: 't2', accountId: 'a2', amount: 200, currency: 'SAR', direction: AccountDirection.debit, date: DateTime(2026, 1, 2)),
      ],
    );
    await container.read(accountsProvider.future);
    await container.read(transactionsProvider.future);

    final summary = container.read(accountsSummaryProvider);

    expect(summary.totalCredit, 500);
    expect(summary.totalDebit, 200);
    expect(summary.count, 2);
    expect(summary.net, 300);
  });

  test('filteredAccountsProvider returns only accounts matching the selected category', () async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => [client, supplier]);
    await container.read(accountsProvider.future);

    expect(container.read(filteredAccountsProvider), [client, supplier]); // null = "عام" (all)

    container.read(selectedCategoryProvider.notifier).state = AccountCategory.supplier;
    expect(container.read(filteredAccountsProvider), [supplier]);

    container.read(selectedCategoryProvider.notifier).state = AccountCategory.client;
    expect(container.read(filteredAccountsProvider), [client]);
  });

  test('overallSummaryProvider stays unaffected by selectedCategoryProvider (Reports vs Home)',
      () async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => [client, supplier]);
    when(() => transactionsRepo.getTransactions()).thenAnswer(
      (_) async => [
        Transaction(id: 't1', accountId: 'a1', amount: 500, currency: 'SAR', direction: AccountDirection.credit, date: DateTime(2026, 1, 1)),
        Transaction(id: 't2', accountId: 'a2', amount: 200, currency: 'SAR', direction: AccountDirection.debit, date: DateTime(2026, 1, 2)),
      ],
    );
    await container.read(accountsProvider.future);
    await container.read(transactionsProvider.future);

    // Simulate Home being left on the "موردين" tab...
    container.read(selectedCategoryProvider.notifier).state = AccountCategory.supplier;

    // ...the scoped summary reflects that (only the supplier's numbers)...
    final scoped = container.read(accountsSummaryProvider);
    expect(scoped.count, 1);

    // ...but the overall summary (Reports) must still show BOTH accounts regardless.
    final overall = container.read(overallSummaryProvider);
    expect(overall.count, 2);
    expect(overall.totalCredit, 500);
    expect(overall.totalDebit, 200);
  });
}
