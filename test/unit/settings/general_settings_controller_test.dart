import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dyooni/data/models/general_settings.dart';
import 'package:dyooni/logic/onboarding/onboarding_provider.dart' show sharedPreferencesProvider;
import 'package:dyooni/logic/settings/general_settings_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
  });

  test('build() returns sensible defaults when nothing was saved yet', () async {
    final result = await container.read(generalSettingsProvider.future);

    expect(result.biometricEnabled, isFalse);
    expect(result.passwordEnabled, isFalse);
    expect(result.pinMatchingAccountsOnSearch, isTrue);
    expect(result.defaultDirection, DefaultDirectionOption.keepLast);
  });

  test('setPassword() enables protection and stores only a hash, never the raw password',
      () async {
    await container.read(generalSettingsProvider.future);
    await container.read(generalSettingsProvider.notifier).setPassword('1234');

    final state = container.read(generalSettingsProvider).value!;
    expect(state.passwordEnabled, isTrue);
    expect(state.passwordHash, isNotNull);
    expect(state.passwordHash, isNot('1234'));
  });

  test('verifyPassword() returns true only for the exact password that was set', () async {
    await container.read(generalSettingsProvider.future);
    final notifier = container.read(generalSettingsProvider.notifier);
    await notifier.setPassword('1234');

    expect(notifier.verifyPassword('1234'), isTrue);
    expect(notifier.verifyPassword('0000'), isFalse);
  });

  test('disablePassword() turns protection off and clears the stored hash', () async {
    await container.read(generalSettingsProvider.future);
    final notifier = container.read(generalSettingsProvider.notifier);
    await notifier.setPassword('1234');
    await notifier.disablePassword();

    final state = container.read(generalSettingsProvider).value!;
    expect(state.passwordEnabled, isFalse);
    expect(state.passwordHash, isNull);
  });

  test('setCreditLabel()/setDebitLabel() persist custom عبارات, and clearing restores defaults',
      () async {
    await container.read(generalSettingsProvider.future);
    final notifier = container.read(generalSettingsProvider.notifier);

    await notifier.setCreditLabel('دائن مخصص');
    await notifier.setDebitLabel('مدين مخصص');
    var state = container.read(generalSettingsProvider).value!;
    expect(state.customCreditLabel, 'دائن مخصص');
    expect(state.customDebitLabel, 'مدين مخصص');

    await notifier.setCreditLabel('');
    state = container.read(generalSettingsProvider).value!;
    expect(state.customCreditLabel, isNull);
  });

  test('recordLastUsedDirection() persists the direction for DefaultDirectionOption.keepLast',
      () async {
    await container.read(generalSettingsProvider.future);
    final notifier = container.read(generalSettingsProvider.notifier);

    await notifier.recordLastUsedDirection(isCredit: true);

    final state = container.read(generalSettingsProvider).value!;
    expect(state.lastUsedDirectionIsCredit, isTrue);
  });

  test('a saved GeneralSettings survives a fresh provider container (simulating app restart)',
      () async {
    await container.read(generalSettingsProvider.future);
    await container.read(generalSettingsProvider.notifier).setShowTimeInOperations(false);

    final prefs = await SharedPreferences.getInstance();
    final freshContainer = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(freshContainer.dispose);

    final result = await freshContainer.read(generalSettingsProvider.future);
    expect(result.showTimeInOperations, isFalse);
  });
}
