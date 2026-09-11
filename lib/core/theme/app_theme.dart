import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_shell_colors.dart';

/// Onboarding/auth are always the dark navy+gold brand look, matching the approved reference,
/// regardless of `ThemeMode` — those screens read straight from `AppColors`, not from either
/// theme below, so switching `themeMode` has no visual effect on them at all (by design).
///
/// The app-shell screens (Home and everything after login) DO respond to `themeMode` now, via
/// the `AppShellColors` extension attached to each of these two ThemeData — see
/// app_shell_colors.dart for why that split was necessary.
abstract class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppShellColors.light.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.gold,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        textTheme: const TextTheme().apply(
          bodyColor: AppShellColors.light.textPrimary,
          displayColor: AppShellColors.light.textPrimary,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? AppColors.gold : Colors.transparent,
          ),
          side: const BorderSide(color: AppColors.surfaceBorder, width: 1.4),
        ),
        dividerTheme: const DividerThemeData(color: AppColors.surfaceBorder, thickness: 1),
        extensions: const [AppShellColors.light],
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundTop,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gold,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        textTheme: const TextTheme().apply(
          bodyColor: AppShellColors.dark.textPrimary,
          displayColor: AppShellColors.dark.textPrimary,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? AppColors.gold : Colors.transparent,
          ),
          side: const BorderSide(color: AppColors.surfaceBorder, width: 1.4),
        ),
        dividerTheme: const DividerThemeData(color: AppColors.surfaceBorder, thickness: 1),
        extensions: const [AppShellColors.dark],
      );
}

/// Fills the screen with the navy gradient — used by onboarding/auth screens only, which are
/// unaffected by the light/dark toggle above (see the class doc comment on AppTheme).
///
/// The `SizedBox.expand` here is a defensive addition: `DecoratedBox` alone sizes itself to its
/// child, and while the child (a `SafeArea` → `SingleChildScrollView`) normally already fills the
/// available space on its own, there's no guarantee of that across every edge case (keyboard
/// showing/hiding mid-frame, a transient constraint change) — which matches the intermittent
/// "sometimes the white gap under the overflow appears, sometimes it doesn't" behavior reported
/// against the login screen. Forcing `SizedBox.expand` makes the fill deterministic instead of
/// incidental. The far more likely PRIMARY cause of that white gap was the RenderFlex overflow
/// itself (fixed separately in login_screen.dart/signup_screen.dart) corrupting that frame's
/// paint — this is a belt-and-suspenders hardening on top of that real fix, not a replacement
/// for it.
class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
        ),
      ),
      child: SizedBox.expand(child: child),
    );
  }
}
