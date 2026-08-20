import 'package:flutter/material.dart';

/// The post-login "app shell" (Home, Add Account, Account Details, Add Transaction, Reports)
/// used to read colors straight from `AppColors.appXxx` — `static const` fields, fixed at compile
/// time. That's WHY no theme toggle could ever exist before: a const can't change while the app
/// is running. This extension is the fix — every app-shell screen now reads colors through
/// `Theme.of(context).extension<AppShellColors>()!` instead, so switching `ThemeMode` genuinely
/// changes what's drawn.
///
/// Onboarding/auth screens are UNAFFECTED by any of this — they still read their navy+gold colors
/// directly from `AppColors`, by design (see app_colors.dart), and always will.
class AppShellColors extends ThemeExtension<AppShellColors> {
  const AppShellColors({
    required this.background,
    required this.surface,
    required this.headerTop,
    required this.headerBottom,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.badge,
  });

  final Color background;
  final Color surface;
  final Color headerTop;
  final Color headerBottom;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color badge;

  static const light = AppShellColors(
    background: Color(0xFFF7F8F8),
    surface: Color(0xFFFFFFFF),
    headerTop: Color(0xFF021534),
    headerBottom: Color(0xFF011433),
    accent: Color(0xFFCA8906),
    textPrimary: Color(0xFF06142D),
    textSecondary: Color(0xFF657083),
    border: Color(0xFFD8C99F),
    badge: Color(0xFFCA8906),
  );

  static const dark = AppShellColors(
    background: Color(0xFF090D18),
    surface: Color(0xFF121A29),
    headerTop: Color(0xFF151125),
    headerBottom: Color(0xFF071C31),
    accent: Color(0xFFFDC02D),
    textPrimary: Color(0xFFF3F5F8),
    textSecondary: Color(0xFFB5BECD),
    border: Color(0xFF344359),
    badge: Color(0xFFFDC02D),
  );

  @override
  AppShellColors copyWith({
    Color? background,
    Color? surface,
    Color? headerTop,
    Color? headerBottom,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? badge,
  }) {
    return AppShellColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      headerTop: headerTop ?? this.headerTop,
      headerBottom: headerBottom ?? this.headerBottom,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      badge: badge ?? this.badge,
    );
  }

  @override
  AppShellColors lerp(ThemeExtension<AppShellColors>? other, double t) {
    if (other is! AppShellColors) return this;
    return AppShellColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      headerTop: Color.lerp(headerTop, other.headerTop, t)!,
      headerBottom: Color.lerp(headerBottom, other.headerBottom, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      badge: Color.lerp(badge, other.badge, t)!,
    );
  }
}

/// Convenience so call sites read `context.shellColors.background` instead of the longer
/// `Theme.of(context).extension<AppShellColors>()!.background` everywhere.
extension AppShellColorsX on BuildContext {
  AppShellColors get shellColors => Theme.of(this).extension<AppShellColors>()!;
}
