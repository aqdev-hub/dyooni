import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dyooni/core/l10n/generated/app_localizations.dart';
import 'package:dyooni/view/screens/settings/contact_us_screen.dart';

Widget _wrap({Locale locale = const Locale('ar')}) {
  final router = GoRouter(
    initialLocation: '/contact-us',
    routes: [GoRoute(path: '/contact-us', builder: (_, __) => const ContactUsScreen())],
  );

  return MaterialApp.router(
    locale: locale,
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    routerConfig: router,
  );
}

void main() {
  testWidgets('shows the screen title, both team members with their roles, and all three contact actions',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    expect(find.text(l10n.contactUsScreenTitle), findsOneWidget);
    expect(find.text(l10n.contactUsManagementName), findsOneWidget);
    expect(find.text(l10n.contactUsManagementRole), findsOneWidget);
    expect(find.text(l10n.contactUsDevelopmentName), findsOneWidget);
    expect(find.text(l10n.contactUsDevelopmentRole), findsOneWidget);
    expect(find.text(l10n.contactUsWhatsappLabel), findsOneWidget);
    expect(find.text(l10n.contactUsCallLabel), findsOneWidget);
    expect(find.text(l10n.contactUsEmailLabel), findsOneWidget);
  });

  testWidgets('renders correctly in English (LTR) without overflow', (tester) async {
    await tester.pumpWidget(_wrap(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
