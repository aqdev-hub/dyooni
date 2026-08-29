import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dyooni/core/l10n/generated/app_localizations.dart';
import 'package:dyooni/data/repositories/backup/backup_repository.dart';
import 'package:dyooni/logic/backup/backup_provider.dart';
import 'package:dyooni/logic/onboarding/onboarding_provider.dart';
import 'package:dyooni/view/screens/settings/local_backup_screen.dart';

class MockBackupRepository extends Mock implements BackupRepository {}

Widget _wrap(MockBackupRepository repository, SharedPreferences prefs) {
  final router = GoRouter(
    initialLocation: '/local-backup',
    routes: [GoRoute(path: '/local-backup', builder: (_, __) => const LocalBackupScreen())],
  );

  return ProviderScope(
    overrides: [
      backupRepositoryProvider.overrideWithValue(repository),
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
  late MockBackupRepository repository;

  setUp(() {
    repository = MockBackupRepository();
  });

  testWidgets('shows the "never backed up" state when nothing was saved yet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_wrap(repository, prefs));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    expect(find.text(l10n.localBackupScreenTitle), findsOneWidget);
    expect(find.text(l10n.localBackupNeverLabel), findsOneWidget);
    expect(find.text(l10n.localBackupCreateButton), findsOneWidget);
    expect(find.text(l10n.localBackupRestoreButton), findsOneWidget);
  });

  testWidgets('shows the persisted last-backup date instead, when one already exists',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'last_local_backup_at': DateTime(2026, 1, 1, 9, 30).toIso8601String(),
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_wrap(repository, prefs));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    expect(find.text(l10n.localBackupLastLabel('2026-01-01 09:30')), findsOneWidget);
    expect(find.text(l10n.localBackupNeverLabel), findsNothing);
  });
}
