import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dyooni/core/l10n/generated/app_localizations.dart';
import 'package:dyooni/data/repositories/auth/auth_repository.dart';
import 'package:dyooni/logic/auth/auth_provider.dart';
import 'package:dyooni/view/screens/auth/signup_screen.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

Widget _wrap(MockAuthRepository repository) {
  final router = GoRouter(
    initialLocation: '/signup',
    routes: [
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('login'))),
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

Future<void> _fillValidForm(WidgetTester tester, {String confirmPassword = 'password123'}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'أحمد'); // first name
  await tester.enterText(fields.at(1), 'محمد'); // last name
  await tester.enterText(fields.at(2), 'user@example.com'); // email
  await tester.enterText(fields.at(3), '0500000000'); // phone
  await tester.enterText(fields.at(4), 'password123'); // password
  await tester.enterText(fields.at(5), confirmPassword); // confirm password
}

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  testWidgets('shows every signup field and no stepper (dropped by design)', (tester) async {
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(find.text(l10n.signupTitle), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(6));
  });

  testWidgets('rejects submission when passwords do not match, without calling the repository',
      (tester) async {
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await _fillValidForm(tester, confirmPassword: 'different123');
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text(l10n.signupButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n.passwordsDontMatch), findsOneWidget);
    verifyNever(
      () => repository.signUpWithEmail(
        firstName: any(named: 'firstName'),
        lastName: any(named: 'lastName'),
        email: any(named: 'email'),
        phone: any(named: 'phone'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('rejects submission when terms are not accepted, without calling the repository',
      (tester) async {
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await _fillValidForm(tester);
    await tester.tap(find.text(l10n.signupButton));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(l10n.mustAcceptTerms), findsOneWidget);
    verifyNever(
      () => repository.signUpWithEmail(
        firstName: any(named: 'firstName'),
        lastName: any(named: 'lastName'),
        email: any(named: 'email'),
        phone: any(named: 'phone'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('successful signup shows a success message and navigates to home', (tester) async {
    when(
      () => repository.signUpWithEmail(
        firstName: any(named: 'firstName'),
        lastName: any(named: 'lastName'),
        email: any(named: 'email'),
        phone: any(named: 'phone'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await _fillValidForm(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text(l10n.signupButton));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('tapping the login link navigates back to /login', (tester) async {
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.tap(find.text(l10n.loginButton));
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
  });
}
