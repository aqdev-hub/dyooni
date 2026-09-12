import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../logic/settings/theme_mode_provider.dart';

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({this.color, super.key});
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return IconButton(
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: color),
      tooltip: isDark ? l10n.switchToLightMode : l10n.switchToDarkMode,
    );
  }
}
