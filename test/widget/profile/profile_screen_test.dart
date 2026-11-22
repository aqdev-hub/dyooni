import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dyooni/core/l10n/generated/app_localizations.dart';
import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/transaction.dart';
import 'package:dyooni/data/repositories/accounts/accounts_repository.dart';
import 'package:dyooni/data/repositories/auth/auth_repository.dart';
import 'package:dyooni/data/repositories/transactions/transactions_repository.dart';
import 'package:dyooni/logic/accounts/accounts_provider.dart';
import 'package:dyooni/logic/auth/auth_provider.dart';
import 'package:dyooni/logic/onboarding/onboarding_provider.dart' show sharedPreferencesProvider;
import 'package:dyooni/logic/transactions/transactions_provider.dart';
import 'package:dyooni/view/screens/profile/profile_screen.dart';

class _AccountsRepo extends Mock implements AccountsRepository {
  @override
  Stream<List<Account>> watchAccounts() => const Stream.empty();
}

class _TxRepo extends Mock implements TransactionsRepository {
  @override
  Stream<List<Transaction>> watchTransactions() => const Stream.empty();
}

class _AuthRepo extends Mock implements AuthRepository {}

Widget _wrap(_AuthRepo auth, _AccountsRepo accounts, _TxRepo tx, SharedPreferences prefs) {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('login'))),
    ],
  );
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      accountsRepositoryProvider.overrideWithValue(accounts),
      transactionsRepositoryProvider.overrideWithValue(tx),
      sharedPreferencesProvider.overrideWithValue(prefs),
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
  late _AuthRepo auth;
  late _AccountsRepo accounts;
  late _TxRepo tx;
  late SharedPreferences prefs;

  setUp(() async {
    auth = _AuthRepo();
    accounts = _AccountsRepo();
    tx = _TxRepo();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    when(() => accounts.getAccounts()).thenAnswer(
      (_) async => [Account(id: '1', name: 'أحمد محمد', category: AccountCategory.client, createdDate: DateTime(2026, 1, 1))],
    );
    when(() => tx.getTransactions()).thenAnswer(
      (_) async => [Transaction(id: 't1', accountId: '1', amount: 5, currency: 'LOCAL', direction: AccountDirection.credit, date: DateTime(2026, 1, 1))],
    );
    when(() => auth.currentProfile).thenReturn(
      AuthProfile(
        displayName: 'سالم علي',
        email: 'salem@example.com',
        phone: '',
        createdAt: DateTime(2026, 3, 5),
        emailVerified: false,
        providers: const ['password'],
      ),
    );
  });

  testWidgets('shows the person, their activity and the account actions', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(auth, accounts, tx, prefs));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    expect(find.text('سالم علي'), findsOneWidget);
    expect(find.text('salem@example.com'), findsOneWidget);
    expect(find.text(l10n.profilePhoneEmpty), findsOneWidget);
    expect(find.text('2026/03/05'), findsOneWidget);
    expect(find.text(l10n.profileEmailNotVerified), findsOneWidget);
    expect(find.text(l10n.profileChangePassword), findsOneWidget);
    expect(find.text(l10n.drawerLogout), findsOneWidget);
  });

  testWidgets('a Google account has no password-change row', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    when(() => auth.currentProfile).thenReturn(
      const AuthProfile(displayName: 'Salem', email: 'g@example.com', phone: '', emailVerified: true, providers: ['google.com']),
    );

    await tester.pumpWidget(_wrap(auth, accounts, tx, prefs));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    expect(find.text(l10n.profileChangePassword), findsNothing);
    expect(find.text(l10n.profileMethodGoogle), findsOneWidget);
    expect(find.text(l10n.profileEmailVerified), findsOneWidget);
  });

  testWidgets('logging out asks first, then goes to the login screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    when(() => auth.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(auth, accounts, tx, prefs));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.tap(find.text(l10n.drawerLogout));
    await tester.pumpAndSettle();
    expect(find.text(l10n.logoutConfirmTitle), findsOneWidget);
    await tester.tap(find.text(l10n.drawerLogout).last);
    await tester.pumpAndSettle();

    verify(() => auth.signOut()).called(1);
    expect(find.text('login'), findsOneWidget);
  });
}
