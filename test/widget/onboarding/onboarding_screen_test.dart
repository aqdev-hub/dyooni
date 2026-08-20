import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dyooni/core/l10n/generated/app_localizations.dart';
import 'package:dyooni/data/repositories/onboarding/onboarding_repository.dart';
import 'package:dyooni/logic/onboarding/onboarding_provider.dart';
import 'package:dyooni/view/screens/onboarding/onboarding_screen.dart';

class MockOnboardingRepository extends Mock implements OnboardingRepository {}

Widget _wrap(MockOnboardingRepository repository, {Locale locale = const Locale('ar')}) {
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('login'))),
    ],
  );

  return ProviderScope(
    overrides: [onboardingRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    ),
  );
}

Future<void> _tapNext(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.text(l10n.onboardingNext));
  await tester.pumpAndSettle();
}

void main() {
  late MockOnboardingRepository repository;

  setUp(() {
    repository = MockOnboardingRepository();
    when(() => repository.hasSeenOnboarding()).thenAnswer((_) async => false);
    when(() => repository.completeOnboarding()).thenAnswer((_) async {});
  });

  testWidgets('shows the welcome slide with brand name and no "previous" button yet',
      (tester) async {
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(find.text(l10n.onboardingWelcomeTitle), findsOneWidget);
    expect(find.text(l10n.appName), findsOneWidget);
    expect(find.text(l10n.onboardingWelcomeSubtitlePrefix), findsOneWidget);
    expect(find.text(l10n.onboardingPrevious), findsNothing);
  });

  testWidgets('slide order is title -> image -> subtitle (subtitle appears after the title text)',
      (tester) async {
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    final titleTop = tester.getTopLeft(find.text(l10n.appName)).dy;
    final subtitleTop = tester.getTopLeft(find.text(l10n.onboardingWelcomeSubtitlePrefix)).dy;
    // Regression guard for the reported layout bug: subtitle must render BELOW the title/brand
    // line (and, by construction of the widget tree, below the illustration too) — never above.
    expect(subtitleTop, greaterThan(titleTop));
  });

  testWidgets('slide 2 shows its title/subtitle and a "previous" button', (tester) async {
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await _tapNext(tester, l10n);

    expect(find.text(l10n.onboardingTitle2), findsOneWidget);
    expect(find.text(l10n.onboardingBody2), findsOneWidget);
    expect(find.text(l10n.onboardingPrevious), findsOneWidget);
  });

  testWidgets('tapping "previous" goes back to the welcome slide', (tester) async {
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await _tapNext(tester, l10n); // -> slide 2
    await tester.tap(find.text(l10n.onboardingPrevious));
    await tester.pumpAndSettle();

    expect(find.text(l10n.onboardingWelcomeTitle), findsOneWidget);
  });

  testWidgets('completing the last slide calls completeOnboarding and navigates to login',
      (tester) async {
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await _tapNext(tester, l10n); // -> slide 2
    await _tapNext(tester, l10n); // -> slide 3
    await _tapNext(tester, l10n); // -> slide 4

    expect(find.text(l10n.onboardingStart), findsOneWidget);
    expect(find.text(l10n.onboardingPrevious), findsOneWidget);

    await tester.tap(find.text(l10n.onboardingStart));
    await tester.pumpAndSettle();

    verify(() => repository.completeOnboarding()).called(1);
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('renders correctly in English (LTR) without overflow', (tester) async {
    await tester.pumpWidget(_wrap(repository, locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders every slide without overflow (regression test for the reported overflow bug)',
      (tester) async {
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    for (var i = 0; i < 3; i++) {
      await _tapNext(tester, l10n);
      expect(tester.takeException(), isNull);
    }
  });
}
