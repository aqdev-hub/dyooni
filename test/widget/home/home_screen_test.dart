import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dyooni/core/l10n/generated/app_localizations.dart';
import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/transaction.dart';
import 'package:dyooni/data/repositories/accounts/accounts_repository.dart';
import 'package:dyooni/data/repositories/auth/auth_repository.dart';
import 'package:dyooni/data/repositories/transactions/transactions_repository.dart';
import 'package:dyooni/logic/accounts/accounts_provider.dart';
import 'package:dyooni/logic/auth/auth_provider.dart';
import 'package:dyooni/logic/transactions/transactions_provider.dart';
import 'package:dyooni/view/screens/home/home_screen.dart';

class MockAccountsRepository extends Mock implements AccountsRepository {}

class MockTransactionsRepository extends Mock implements TransactionsRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

final _client = Account(id: '1', name: 'أحمد محمد', category: AccountCategory.client, createdDate: DateTime(2026, 1, 1));
final _supplier = Account(id: '2', name: 'سالم علي', category: AccountCategory.supplier, createdDate: DateTime(2026, 1, 2));

List<Override> _overrides(MockAccountsRepository accountsRepo, MockTransactionsRepository txRepo, MockAuthRepository authRepo) => [
      accountsRepositoryProvider.overrideWithValue(accountsRepo),
      transactionsRepositoryProvider.overrideWithValue(txRepo),
      authRepositoryProvider.overrideWithValue(authRepo),
    ];

Widget _wrap(MockAccountsRepository accountsRepo, MockTransactionsRepository txRepo, MockAuthRepository authRepo) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/add-account', builder: (_, __) => const Scaffold(body: Text('add-account'))),
      GoRoute(path: '/account-details', builder: (_, __) => const Scaffold(body: Text('account-details'))),
      GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('login'))),
    ],
  );

  return ProviderScope(
    overrides: _overrides(accountsRepo, txRepo, authRepo),
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
  late MockAuthRepository authRepo;

  setUp(() {
    accountsRepo = MockAccountsRepository();
    txRepo = MockTransactionsRepository();
    authRepo = MockAuthRepository();
    when(() => txRepo.getTransactions()).thenAnswer((_) async => []);
  });

  testWidgets('shows the empty state when there are no accounts yet', (tester) async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(accountsRepo, txRepo, authRepo));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(find.text(l10n.homeEmptyAccounts), findsOneWidget);
  });

  testWidgets('renders the account list with a balance derived from its transactions', (tester) async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => [_client]);
    when(() => txRepo.getTransactions()).thenAnswer(
      (_) async => [
        Transaction(id: 't1', accountId: '1', amount: 500, currency: 'SAR', direction: AccountDirection.credit, date: DateTime(2026, 1, 1)),
      ],
    );

    await tester.pumpWidget(_wrap(accountsRepo, txRepo, authRepo));
    await tester.pumpAndSettle();

    expect(find.text('أحمد محمد'), findsOneWidget);
    expect(find.text('500'), findsWidgets);
  });

  testWidgets('tapping the FAB navigates to add-account', (tester) async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(accountsRepo, txRepo, authRepo));
    await tester.pumpAndSettle();

    // The FAB is icon-only now (tooltip carries the label, matching the reference's compact
    // FAB) — tap by widget type instead of visible text.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('add-account'), findsOneWidget);
  });

  testWidgets('opening the drawer and confirming logout calls signOut and navigates to login',
      (tester) async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => []);
    when(() => authRepo.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(accountsRepo, txRepo, authRepo));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.drawerLogout));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.drawerLogout).last);
    await tester.pumpAndSettle();

    verify(() => authRepo.signOut()).called(1);
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets(
      'logout still navigates to login immediately even if signOut() throws — regression test '
      'for the "stuck on Home until app restart" bug', (tester) async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => []);
    // Simulates the real-world case that caused the bug: Google/Facebook's plugins throwing on
    // sign-out when that specific provider was never actually used for this session.
    when(() => authRepo.signOut()).thenThrow(Exception('provider had no active session'));

    await tester.pumpWidget(_wrap(accountsRepo, txRepo, authRepo));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.drawerLogout));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.drawerLogout).last);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('switching to the "موردين" tab filters the list to suppliers only', (tester) async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => [_client, _supplier]);

    await tester.pumpWidget(_wrap(accountsRepo, txRepo, authRepo));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    expect(find.text('أحمد محمد'), findsOneWidget);
    expect(find.text('سالم علي'), findsOneWidget);

    await tester.tap(find.text(l10n.homeTabSuppliers));
    await tester.pumpAndSettle();

    expect(find.text('أحمد محمد'), findsNothing);
    expect(find.text('سالم علي'), findsOneWidget);
  });

  testWidgets('tapping an account row navigates to account details', (tester) async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => [_client]);

    await tester.pumpWidget(_wrap(accountsRepo, txRepo, authRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('أحمد محمد'));
    await tester.pumpAndSettle();

    expect(find.text('account-details'), findsOneWidget);
  });

  testWidgets('tapping the PDF/XLS icon navigates to reports', (tester) async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => []);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/reports', builder: (_, __) => const Scaffold(body: Text('reports'))),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(accountsRepo, txRepo, authRepo),
        child: MaterialApp.router(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.picture_as_pdf_outlined));
    await tester.pumpAndSettle();

    expect(find.text('reports'), findsOneWidget);
  });
}
