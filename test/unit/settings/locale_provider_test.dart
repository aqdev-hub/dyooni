import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dyooni/logic/onboarding/onboarding_provider.dart';
import 'package:dyooni/logic/settings/locale_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
  });

  test('defaults to Arabic when nothing has been saved yet', () {
    expect(container.read(localeProvider), const Locale('ar'));
  });

  test('toggle() flips between ar and en and persists the choice', () async {
    await container.read(localeProvider.notifier).toggle();
    expect(container.read(localeProvider), const Locale('en'));

    await container.read(localeProvider.notifier).toggle();
    expect(container.read(localeProvider), const Locale('ar'));
  });

  test('persisted choice survives a fresh provider container (simulating app restart)', () async {
    await container.read(localeProvider.notifier).toggle(); // -> en

    final prefs = await SharedPreferences.getInstance();
    final freshContainer = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(freshContainer.dispose);

    expect(freshContainer.read(localeProvider), const Locale('en'));
  });
}
