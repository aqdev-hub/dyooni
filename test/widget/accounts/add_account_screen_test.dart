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
import 'package:dyooni/view/screens/accounts/add_account_screen.dart';

class MockAccountsRepository extends Mock implements AccountsRepository {}

class MockTransactionsRepository extends Mock implements TransactionsRepository {}

Widget _wrap(MockAccountsRepository accountsRepo, MockTransactionsRepository txRepo) {
  final router = GoRouter(
    initialLocation: '/add-account',
    routes: [GoRoute(path: '/add-account', builder: (_, __) => const AddAccountScreen())],
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
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => []);
    when(() => txRepo.getTransactions()).thenAnswer((_) async => []);
  });

  testWidgets('rejects submission with an empty name and an invalid amount', (tester) async {
    await tester.pumpWidget(_wrap(accountsRepo, txRepo));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.tap(find.text(l10n.saveButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n.fieldRequired), findsOneWidget);
    expect(find.text(l10n.invalidAmount), findsOneWidget);
    verifyNever(() => accountsRepo.addAccount(any()));
    verifyNever(() => txRepo.addTransaction(any()));
  });

  testWidgets('saving a valid account creates BOTH the account and its first transaction',
      (tester) async {
    when(() => accountsRepo.addAccount(any())).thenAnswer((_) async {});
    when(() => txRepo.addTransaction(any())).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(accountsRepo, txRepo));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'أحمد محمد');
    await tester.enterText(fields.at(1), '500');
    await tester.tap(find.text(l10n.saveButton));
    await tester.pump();
    await tester.pumpAndSettle();

    verify(() => accountsRepo.addAccount(any())).called(1);
    verify(() => txRepo.addTransaction(any())).called(1);
    expect(find.text(l10n.accountSavedSuccessMessage), findsOneWidget);
  });

  testWidgets('the created transaction carries the amount and direction entered in the form',
      (tester) async {
    Transaction? captured;
    when(() => accountsRepo.addAccount(any())).thenAnswer((_) async {});
    when(() => txRepo.addTransaction(any())).thenAnswer((invocation) async {
      captured = invocation.positionalArguments.first as Transaction;
    });

    await tester.pumpWidget(_wrap(accountsRepo, txRepo));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'أحمد محمد');
    await tester.enterText(fields.at(1), '750');
    await tester.tap(find.text(l10n.saveButton));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(captured?.amount, 750);
    expect(captured?.direction, AccountDirection.debit); // matches the reference's default
  });

  testWidgets('saving with the "supplier" category selected persists that category on the account',
      (tester) async {
    Account? captured;
    when(() => accountsRepo.addAccount(any())).thenAnswer((invocation) async {
      captured = invocation.positionalArguments.first as Account;
    });
    when(() => txRepo.addTransaction(any())).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(accountsRepo, txRepo));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'مورد الأجهزة');
    await tester.enterText(fields.at(1), '1200');
    await tester.tap(find.text(l10n.categorySupplier));
    await tester.tap(find.text(l10n.saveButton));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(captured?.category, AccountCategory.supplier);
  });
}
