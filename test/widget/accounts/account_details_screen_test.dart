import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dyooni/core/l10n/generated/app_localizations.dart';
import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/transaction.dart';
import 'package:dyooni/data/repositories/accounts/accounts_repository.dart';
import 'package:dyooni/data/repositories/transactions/transactions_repository.dart';
import 'package:dyooni/logic/accounts/accounts_provider.dart';
import 'package:dyooni/logic/transactions/transactions_provider.dart';
import 'package:dyooni/view/screens/accounts/account_details_screen.dart';

class MockAccountsRepository extends Mock implements AccountsRepository {}

class MockTransactionsRepository extends Mock implements TransactionsRepository {}

final _account = Account(
  id: '1',
  name: 'أحمد محمد',
  category: AccountCategory.client,
  createdDate: DateTime(2026, 1, 1),
  phone: '0500000000',
);

Widget _wrap(MockAccountsRepository accountsRepo, MockTransactionsRepository txRepo) {
  final router = GoRouter(
    initialLocation: '/account-details',
    routes: [
      GoRoute(path: '/account-details', builder: (_, __) => AccountDetailsScreen(account: _account)),
      GoRoute(path: '/add-transaction', builder: (_, __) => const Scaffold(body: Text('add-transaction'))),
      GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('home'))),
    ],
  );

  return ProviderScope(
    overrides: [
      accountsRepositoryProvider.overrideWithValue(accountsRepo),
      transactionsRepositoryProvider.overrideWithValue(txRepo),
    ],
    child: MaterialApp.router(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    ),
  );
}

void main() {
  late MockAccountsRepository accountsRepo;
  late MockTransactionsRepository txRepo;

  setUp(() {
    accountsRepo = MockAccountsRepository();
    txRepo = MockTransactionsRepository();
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => [_account]);
  });

  testWidgets('shows the account name in the header', (tester) async {
    when(() => txRepo.getTransactions()).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(accountsRepo, txRepo));
    await tester.pumpAndSettle();

    expect(find.text('أحمد محمد'), findsOneWidget);
  });

  testWidgets('shows the empty-history message when the account has no transactions',
      (tester) async {
    when(() => txRepo.getTransactions()).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(accountsRepo, txRepo));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    expect(find.text(l10n.noTransactionsYet), findsOneWidget);
  });

  testWidgets('lists each transaction entry for this account in the table', (tester) async {
    when(() => txRepo.getTransactions()).thenAnswer(
      (_) async => [
        Transaction(id: 't1', accountId: '1', amount: 500, currency: 'SAR', direction: AccountDirection.credit, date: DateTime(2026, 1, 1), details: 'دفعة أولى'),
        Transaction(id: 't2', accountId: '1', amount: 100, currency: 'SAR', direction: AccountDirection.debit, date: DateTime(2026, 1, 5), details: 'سحب جزئي'),
      ],
    );

    await tester.pumpWidget(_wrap(accountsRepo, txRepo));
    await tester.pumpAndSettle();

    expect(find.text('دفعة أولى'), findsOneWidget);
    expect(find.text('سحب جزئي'), findsOneWidget);
  });

  testWidgets('tapping the document action opens add-transaction as a modal',
      (tester) async {
    when(() => txRepo.getTransactions()).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(accountsRepo, txRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.note_add_rounded));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(find.text(l10n.addTransactionTitle), findsOneWidget);
  });

  testWidgets('cancelling the delete confirmation (reached via the 3-dot menu) keeps the account',
      (tester) async {
    when(() => txRepo.getTransactions()).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(accountsRepo, txRepo));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();

    verifyNever(() => accountsRepo.deleteAccount(any()));
    expect(find.text('أحمد محمد'), findsOneWidget);
  });

  testWidgets(
      'confirming delete (via the 3-dot menu) removes the account AND cascades to its transactions',
      (tester) async {
    when(() => txRepo.getTransactions()).thenAnswer((_) async => []);
    when(() => accountsRepo.deleteAccount('1')).thenAnswer((_) async {});
    when(() => txRepo.deleteTransactionsForAccount('1')).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(accountsRepo, txRepo));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.delete));
    await tester.pumpAndSettle();
    // The confirm dialog's own button also reads l10n.delete — it's the one still visible
    // after the popup menu closes, so `.last` reliably targets it.
    await tester.tap(find.text(l10n.delete).last);
    await tester.pump();
    await tester.pumpAndSettle();

    verify(() => accountsRepo.deleteAccount('1')).called(1);
    verify(() => txRepo.deleteTransactionsForAccount('1')).called(1);
    expect(find.text(l10n.accountDeletedSuccessMessage), findsOneWidget);
  });
}
