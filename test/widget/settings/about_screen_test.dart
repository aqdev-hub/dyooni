import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dyooni/core/l10n/generated/app_localizations.dart';
import 'package:dyooni/core/utils/app_version.dart';
import 'package:dyooni/view/screens/settings/about_screen.dart';

Widget _wrap({Locale locale = const Locale('ar')}) {
  final router = GoRouter(
    initialLocation: '/about',
    routes: [
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
      GoRoute(path: '/contact-us', builder: (_, __) => const Scaffold(body: Text('contact-us'))),
    ],
  );

  return MaterialApp.router(
    locale: locale,
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    routerConfig: router,
  );
}

void main() {
  testWidgets('shows the tagline, every feature title, the version, and both team members',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    expect(find.text(l10n.aboutScreenTitle), findsOneWidget);
    expect(find.text(l10n.aboutTagline), findsOneWidget);
    expect(find.text(l10n.aboutFeatureAccountsTitle), findsOneWidget);
    expect(find.text(l10n.aboutFeatureVoiceTitle), findsOneWidget);
    expect(find.text(l10n.aboutFeatureReportsTitle), findsOneWidget);
    expect(find.text(l10n.aboutFeatureLocalBackupTitle), findsOneWidget);
    expect(find.text(l10n.aboutFeatureDriveBackupTitle), findsOneWidget);
    expect(find.text(l10n.aboutFeatureAuthTitle), findsOneWidget);
    expect(find.text(l10n.aboutFeatureBilingualTitle), findsOneWidget);
    expect(find.text(l10n.aboutVersionLabel(kAppVersion)), findsOneWidget);
    expect(find.text(l10n.contactUsManagementName), findsOneWidget);
    expect(find.text(l10n.contactUsDevelopmentName), findsOneWidget);
  });

  testWidgets('tapping the contact-us button navigates to /contact-us', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.tap(find.text(l10n.drawerContactUs));
    await tester.pumpAndSettle();

    expect(find.text('contact-us'), findsOneWidget);
  });

  testWidgets('renders correctly in English (LTR) without overflow', (tester) async {
    await tester.pumpWidget(_wrap(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
