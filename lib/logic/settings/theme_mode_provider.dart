import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../onboarding/onboarding_provider.dart' show sharedPreferencesProvider;

/// Controls the app-shell's light/dark appearance (see core/theme/app_shell_colors.dart for why
/// this needed a real ThemeExtension, not just a bool flag read by widgets directly). Defaults to
/// light, matching the originally-approved app-shell reference design.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_key);
    return saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    await ref.read(sharedPreferencesProvider).setString(_key, next == ThemeMode.dark ? 'dark' : 'light');
  }
}
