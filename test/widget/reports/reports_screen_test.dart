import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dyooni/core/l10n/generated/app_localizations.dart';
import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/transaction.dart';
import 'package:dyooni/data/repositories/accounts/accounts_repository.dart';
import 'package:dyooni/data/repositories/settings/personal_data_repository.dart';
import 'package:dyooni/data/repositories/transactions/transactions_repository.dart';
import 'package:dyooni/data/models/personal_data.dart';
import 'package:dyooni/logic/accounts/accounts_provider.dart';
import 'package:dyooni/logic/settings/personal_data_provider.dart';
import 'package:dyooni/logic/transactions/transactions_provider.dart';
import 'package:dyooni/view/screens/reports/reports_screen.dart';

class MockAccountsRepository extends Mock implements AccountsRepository {}

class MockTransactionsRepository extends Mock implements TransactionsRepository {}

class MockPersonalDataRepository extends Mock implements PersonalDataRepository {}

final _client = Account(id: '1', name: 'أحمد محمد', category: AccountCategory.client, createdDate: DateTime(2026, 1, 1));
final _supplier = Account(id: '2', name: 'سالم علي', category: AccountCategory.supplier, createdDate: DateTime(2026, 1, 2));

Widget _wrap(MockAccountsRepository accountsRepo, MockTransactionsRepository txRepo, MockPersonalDataRepository personalDataRepo) {
  final router = GoRouter(
    initialLocation: '/reports',
    routes: [GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen())],
  );

  return ProviderScope(
    overrides: [
      accountsRepositoryProvider.overrideWithValue(accountsRepo),
      transactionsRepositoryProvider.overrideWithValue(txRepo),
      personalDataRepositoryProvider.overrideWithValue(personalDataRepo),
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
  late MockPersonalDataRepository personalDataRepo;

  setUp(() {
    accountsRepo = MockAccountsRepository();
    txRepo = MockTransactionsRepository();
    personalDataRepo = MockPersonalDataRepository();
    when(() => personalDataRepo.getPersonalData()).thenAnswer((_) async => PersonalData.dyooniDefault);
  });

  testWidgets('shows the overall summary totals across both categories, unfiltered', (tester) async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => [_client, _supplier]);
    when(() => txRepo.getTransactions()).thenAnswer(
      (_) async => [
        Transaction(id: 't1', accountId: '1', amount: 500, currency: 'SAR', direction: AccountDirection.credit, date: DateTime(2026, 1, 1)),
        Transaction(id: 't2', accountId: '2', amount: 200, currency: 'SAR', direction: AccountDirection.debit, date: DateTime(2026, 1, 2)),
      ],
    );

    await tester.pumpWidget(_wrap(accountsRepo, txRepo, personalDataRepo));
    await tester.pumpAndSettle();

    expect(find.text('500'), findsWidgets);
    expect(find.text('200'), findsWidgets);
    expect(find.text('أحمد محمد'), findsOneWidget);
    expect(find.text('سالم علي'), findsOneWidget);
  });

  testWidgets('filtering by "موردين" shows only supplier accounts in the breakdown', (tester) async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => [_client, _supplier]);
    when(() => txRepo.getTransactions()).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(accountsRepo, txRepo, personalDataRepo));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.tap(find.text(l10n.homeTabSuppliers));
    await tester.pumpAndSettle();

    expect(find.text('أحمد محمد'), findsNothing);
    expect(find.text('سالم علي'), findsOneWidget);
  });

  testWidgets('shows the empty message when there are no accounts', (tester) async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => []);
    when(() => txRepo.getTransactions()).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(accountsRepo, txRepo, personalDataRepo));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    expect(find.text(l10n.reportsEmpty), findsOneWidget);
  });

  testWidgets('tapping "التقارير" opens the report-options sheet with all five summary report types',
      (tester) async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => []);
    when(() => txRepo.getTransactions()).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(accountsRepo, txRepo, personalDataRepo));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    // The button itself, then the sheet's own copy of the same title once opened.
    expect(find.text(l10n.reportsSheetTitle), findsOneWidget);

    await tester.tap(find.text(l10n.reportsSheetTitle));
    await tester.pumpAndSettle();

    expect(find.text(l10n.reportsSheetTitle), findsWidgets);
    expect(find.text(l10n.reportTypeTotalAmounts), findsOneWidget);
    expect(find.text(l10n.reportTypeAllAmountsDetails), findsOneWidget);
    expect(find.text(l10n.reportTypeMonthlyTotals), findsOneWidget);
    expect(find.text(l10n.reportTypeCategoryAndCurrencyTotals), findsOneWidget);
    expect(find.text(l10n.reportTypeMonthlyDetailsCurrentCategory), findsOneWidget);
    expect(find.text(l10n.reportShowSortOptions), findsOneWidget);
    expect(find.text(l10n.reportSetDateRange), findsOneWidget);

    // The actual PDF/CSV generation and native print/share sheets are platform-channel
    // integrations (printing, share_plus, path_provider) — genuinely an OS-integration boundary
    // that isn't meaningfully covered by a widget test; see test/unit/reports/ for the pure
    // logic (CSV formatting, Arabic shaping) that IS unit-tested, and README for why real
    // on-device testing is still needed for the export actions themselves.
  });
}
