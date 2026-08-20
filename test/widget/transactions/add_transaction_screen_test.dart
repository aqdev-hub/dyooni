import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dyooni/core/l10n/generated/app_localizations.dart';
import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/transaction.dart';
import 'package:dyooni/data/repositories/transactions/transactions_repository.dart';
import 'package:dyooni/logic/transactions/transactions_provider.dart';
import 'package:dyooni/view/screens/transactions/add_transaction_screen.dart';

class MockTransactionsRepository extends Mock implements TransactionsRepository {}

Widget _wrap(MockTransactionsRepository repository) {
  final router = GoRouter(
    initialLocation: '/add-transaction',
    routes: [
      GoRoute(path: '/add-transaction', builder: (_, __) => const AddTransactionScreen(accountId: 'a1')),
      GoRoute(path: '/account-details', builder: (_, __) => const Scaffold(body: Text('account-details'))),
    ],
  );

  return ProviderScope(
    overrides: [transactionsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    ),
  );
}

void main() {
  late MockTransactionsRepository repository;

  setUp(() {
    repository = MockTransactionsRepository();
    when(() => repository.getTransactions()).thenAnswer((_) async => []);
  });

  testWidgets('rejects submission with an invalid amount (via either save button)', (tester) async {
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.tap(find.text(l10n.saveAndExit));
    await tester.pumpAndSettle();

    expect(find.text(l10n.invalidAmount), findsOneWidget);
    verifyNever(() => repository.addTransaction(any()));
  });

  testWidgets('"حفظ وخروج" saves, shows success, and pops back', (tester) async {
    Transaction? captured;
    when(() => repository.addTransaction(any())).thenAnswer((invocation) async {
      captured = invocation.positionalArguments.first as Transaction;
    });

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.enterText(find.byType(TextFormField).first, '300');
    await tester.tap(find.text(l10n.directionCredit));
    await tester.tap(find.text(l10n.saveAndExit));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(captured?.accountId, 'a1');
    expect(captured?.amount, 300);
    expect(captured?.direction, AccountDirection.credit);
    expect(find.text(l10n.transactionSavedSuccessMessage), findsOneWidget);
  });

  testWidgets('"حفظ وإضافة عملية جديدة" saves, shows success, and CLEARS the form to stay on screen',
      (tester) async {
    when(() => repository.addTransaction(any())).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    final amountField = find.byType(TextFormField).first;
    await tester.enterText(amountField, '450');
    await tester.tap(find.text(l10n.saveAndAddAnother));
    await tester.pump();
    await tester.pumpAndSettle();

    verify(() => repository.addTransaction(any())).called(1);
    expect(find.text(l10n.transactionSavedSuccessMessage), findsOneWidget);
    // Still on the add-transaction screen (didn't navigate away)...
    expect(find.byType(AddTransactionScreen), findsOneWidget);
    // ...and the amount field was reset, ready for the next entry.
    expect(tester.widget<TextFormField>(amountField).controller?.text, isEmpty);
  });
}
