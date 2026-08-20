import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dyooni/core/l10n/generated/app_localizations.dart';
import 'package:dyooni/data/models/personal_data.dart';
import 'package:dyooni/data/repositories/settings/personal_data_repository.dart';
import 'package:dyooni/logic/settings/personal_data_provider.dart';
import 'package:dyooni/view/screens/settings/personal_data_screen.dart';

class MockPersonalDataRepository extends Mock implements PersonalDataRepository {}

Widget _wrap(MockPersonalDataRepository repository) {
  final router = GoRouter(
    initialLocation: '/personal-data',
    routes: [GoRoute(path: '/personal-data', builder: (_, __) => const PersonalDataScreen())],
  );

  return ProviderScope(
    overrides: [personalDataRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    ),
  );
}

void main() {
  late MockPersonalDataRepository repository;

  setUpAll(() {
    registerFallbackValue(PersonalData.dyooniDefault);
  });

  setUp(() {
    repository = MockPersonalDataRepository();
    when(() => repository.getPersonalData()).thenAnswer((_) async => PersonalData.dyooniDefault);
  });

  testWidgets('pre-fills Dyooni\'s own default name when nothing was saved yet', (tester) async {
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('ديوني'), findsWidgets); // header title AND the pre-filled Arabic-name field
    expect(find.text('Dyooni'), findsOneWidget); // the pre-filled English-name field
  });

  testWidgets('editing the Arabic name and saving persists the new value', (tester) async {
    when(() => repository.savePersonalData(any())).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.enterText(find.byType(TextFormField).first, 'اسم جديد');
    await tester.tap(find.text(l10n.saveButton));
    await tester.pump();
    await tester.pumpAndSettle();

    final captured = verify(() => repository.savePersonalData(captureAny())).captured.single as PersonalData;
    expect(captured.nameAr, 'اسم جديد');
    expect(find.text(l10n.personalDataSavedMessage), findsOneWidget);
  });
}
