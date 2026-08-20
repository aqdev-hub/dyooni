import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/transaction.dart';
import 'package:dyooni/data/repositories/transactions/transactions_repository.dart';
import 'package:dyooni/logic/transactions/transactions_provider.dart';

class MockTransactionsRepository extends Mock implements TransactionsRepository {}

void main() {
  late MockTransactionsRepository repository;
  late ProviderContainer container;

  final credit = Transaction(
    id: 't1',
    accountId: 'a1',
    amount: 500,
    currency: 'SAR',
    direction: AccountDirection.credit,
    date: DateTime(2026, 1, 1),
  );
  final debit = Transaction(
    id: 't2',
    accountId: 'a1',
    amount: 200,
    currency: 'SAR',
    direction: AccountDirection.debit,
    date: DateTime(2026, 1, 2),
  );
  final otherAccount = Transaction(
    id: 't3',
    accountId: 'a2',
    amount: 999,
    currency: 'SAR',
    direction: AccountDirection.credit,
    date: DateTime(2026, 1, 3),
  );

  setUp(() {
    repository = MockTransactionsRepository();
    container = ProviderContainer(
      overrides: [transactionsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  test('build() loads every transaction from the repository', () async {
    when(() => repository.getTransactions()).thenAnswer((_) async => [credit, debit]);

    final result = await container.read(transactionsProvider.future);

    expect(result, [credit, debit]);
  });

  test('addTransaction() persists via the repository and appends to state', () async {
    when(() => repository.getTransactions()).thenAnswer((_) async => []);
    when(() => repository.addTransaction(any())).thenAnswer((_) async {});

    await container.read(transactionsProvider.future);
    await container.read(transactionsProvider.notifier).addTransaction(credit);

    verify(() => repository.addTransaction(credit)).called(1);
    expect(container.read(transactionsProvider).value, [credit]);
  });

  test('transactionsForAccountProvider only returns entries for that account', () async {
    when(() => repository.getTransactions()).thenAnswer((_) async => [credit, debit, otherAccount]);
    await container.read(transactionsProvider.future);

    final forA1 = container.read(transactionsForAccountProvider('a1'));

    expect(forA1, [credit, debit]);
    expect(container.read(transactionsForAccountProvider('a2')), [otherAccount]);
  });

  test('accountBalanceProvider nets credit minus debit for that account only', () async {
    when(() => repository.getTransactions()).thenAnswer((_) async => [credit, debit, otherAccount]);
    await container.read(transactionsProvider.future);

    expect(container.read(accountBalanceProvider('a1')), 300); // 500 - 200
    expect(container.read(accountBalanceProvider('a2')), 999);
  });

  test('accountDirectionProvider reflects the sign of the net balance', () async {
    when(() => repository.getTransactions()).thenAnswer((_) async => [debit]); // net -200
    await container.read(transactionsProvider.future);

    expect(container.read(accountDirectionProvider('a1')), AccountDirection.debit);
  });

  test('accountTransactionCountProvider counts entries for that account', () async {
    when(() => repository.getTransactions()).thenAnswer((_) async => [credit, debit, otherAccount]);
    await container.read(transactionsProvider.future);

    expect(container.read(accountTransactionCountProvider('a1')), 2);
    expect(container.read(accountTransactionCountProvider('a2')), 1);
  });

  test('deleteForAccount() removes every transaction for that account only', () async {
    when(() => repository.getTransactions()).thenAnswer((_) async => [credit, debit, otherAccount]);
    when(() => repository.deleteTransactionsForAccount('a1')).thenAnswer((_) async {});
    await container.read(transactionsProvider.future);

    await container.read(transactionsProvider.notifier).deleteForAccount('a1');

    verify(() => repository.deleteTransactionsForAccount('a1')).called(1);
    expect(container.read(transactionsProvider).value, [otherAccount]);
  });
}
