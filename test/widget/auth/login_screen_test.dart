import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dyooni/core/l10n/generated/app_localizations.dart';
import 'package:dyooni/data/repositories/auth/auth_repository.dart';
import 'package:dyooni/logic/auth/auth_provider.dart';
import 'package:dyooni/view/screens/auth/login_screen.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

Widget _wrap(MockAuthRepository repository) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const Scaffold(body: Text('signup'))),
      GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('home'))),
    ],
  );

  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    ),
  );
}

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  testWidgets('shows the login form and both social buttons (Google + Facebook)', (tester) async {
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(find.text(l10n.loginWelcomeTitle), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Facebook'), findsOneWidget);
  });

  testWidgets('shows validation errors when submitting an empty form', (tester) async {
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.tap(find.text(l10n.loginButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n.fieldRequired), findsWidgets);
    verifyNever(
      () => repository.signInWithEmail(
        identifier: any(named: 'identifier'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('successful login shows a success message and navigates to home', (tester) async {
    when(
      () => repository.signInWithEmail(
        identifier: any(named: 'identifier'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text(l10n.loginButton));
    await tester.pump(); // start the snackbar animation
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('failed login shows a real error message and stays on the login screen',
      (tester) async {
    when(
      () => repository.signInWithEmail(
        identifier: any(named: 'identifier'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const _FakeInvalidCredentials());

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'wrongpass');
    await tester.tap(find.text(l10n.loginButton));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(l10n.invalidCredentials), findsOneWidget);
    expect(find.text(l10n.loginWelcomeTitle), findsOneWidget); // still on login
  });

  testWidgets('tapping "create account" navigates to signup', (tester) async {
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.tap(find.text(l10n.createAccount));
    await tester.pumpAndSettle();

    expect(find.text('signup'), findsOneWidget);
  });

  testWidgets('forgot password sends a reset email and shows a success message', (tester) async {
    when(() => repository.sendPasswordResetEmail(any())).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.tap(find.text(l10n.forgotPassword));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'user@example.com');
    await tester.tap(find.text(l10n.sendResetLink));
    await tester.pump();
    await tester.pumpAndSettle();

    verify(() => repository.sendPasswordResetEmail('user@example.com')).called(1);
    expect(find.text(l10n.forgotPasswordEmailSentMessage), findsOneWidget);
  });
}

class _FakeInvalidCredentials implements Exception {
  const _FakeInvalidCredentials();
  String get code => 'invalidCredentials';
}
