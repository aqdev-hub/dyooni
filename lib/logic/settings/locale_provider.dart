import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../onboarding/onboarding_provider.dart' show sharedPreferencesProvider;

/// Persisted app language — previously only ever hardcoded to `Locale('ar')` in main.dart with
/// no way to change it, despite both `ar`/`en` ARB files existing since the very first onboarding
/// batch. This provider is what actually makes the language switchable now.
final localeProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);

class LocaleController extends Notifier<Locale> {
  static const _key = 'locale_code';

  @override
  Locale build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_key);
    return saved == 'en' ? const Locale('en') : const Locale('ar');
  }

  Future<void> toggle() async {
    final next = state.languageCode == 'ar' ? const Locale('en') : const Locale('ar');
    state = next;
    await ref.read(sharedPreferencesProvider).setString(_key, next.languageCode);
  }
}
