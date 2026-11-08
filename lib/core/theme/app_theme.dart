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
  static ThemeData get light => _build(Brightness.light, AppShellColors.light, scaffold: AppShellColors.light.background);

  static ThemeData get dark => _build(Brightness.dark, AppShellColors.dark, scaffold: AppColors.backgroundTop);

  /// ONE builder for both themes, so every ready-made Material widget (dialogs, popup menus,
  /// bottom sheets, pickers, snack bars, list tiles, text fields …) takes its background AND its
  /// text/icon colours from the same [AppShellColors] pair and can never disagree.
  ///
  /// Why this matters: the light theme used to set `colorScheme.surface` to the NAVY auth surface
  /// while leaving the default dark text colour — every dialog, menu or picker built with default
  /// colours came out navy with black text (unreadable). Surfaces now come from `shell.surface`
  /// (white in light, dark slate in dark) and are always paired with `shell.textPrimary`.
  static ThemeData _build(Brightness brightness, AppShellColors c, {required Color scaffold}) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.headerBottom,
      secondary: c.accent,
      onSecondary: c.headerBottom,
      error: AppColors.error,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      outline: c.border,
      outlineVariant: c.border,
      // Material 3 paints dialogs, menus, sheets and pickers with the surfaceContainer* roles.
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surface,
      surfaceContainerHighest: c.background,
      surfaceTint: Colors.transparent,
      inverseSurface: c.headerBottom,
      onInverseSurface: Colors.white,
      inversePrimary: AppColors.gold,
      primaryContainer: c.accent.withValues(alpha: isDark ? 0.28 : 0.18),
      onPrimaryContainer: c.textPrimary,
    );

    final bodyStyle = TextStyle(color: c.textPrimary);
    final shape16 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffold,
      colorScheme: scheme,
      textTheme: const TextTheme().apply(bodyColor: c.textPrimary, displayColor: c.textPrimary),
      iconTheme: IconThemeData(color: c.textPrimary),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.gold : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(c.headerBottom),
        side: const BorderSide(color: AppColors.surfaceBorder, width: 1.4),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: shape16,
        titleTextStyle: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
        contentTextStyle: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.5),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
        textStyle: bodyStyle,
        iconColor: c.textPrimary,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(c.textPrimary))),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: bodyStyle,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      ),
      listTileTheme: ListTileThemeData(
        textColor: c.textPrimary,
        iconColor: c.textSecondary,
        subtitleTextStyle: TextStyle(color: c.textSecondary, fontSize: 13),
      ),
      cardTheme: CardThemeData(color: c.surface, surfaceTintColor: Colors.transparent, elevation: 0),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.headerBottom,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: AppColors.gold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: c.textSecondary),
        labelStyle: TextStyle(color: c.textSecondary),
        floatingLabelStyle: TextStyle(color: c.accent),
        prefixIconColor: c.textSecondary,
        suffixIconColor: c.textSecondary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionHandleColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.35),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: c.accent)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: c.accent)),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.headerBottom),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.accent,
        side: BorderSide(color: c.border),
        labelStyle: TextStyle(color: c.textPrimary),
        secondaryLabelStyle: TextStyle(color: c.headerBottom),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.headerBottom : c.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : c.border,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStatePropertyAll(c.accent)),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.headerBottom, borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.headerBottom,
        headerForegroundColor: AppColors.gold,
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.headerBottom : c.textPrimary,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : Colors.transparent,
        ),
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.headerBottom : c.textPrimary,
        ),
        todayBorder: BorderSide(color: c.accent),
        yearForegroundColor: WidgetStatePropertyAll(c.textPrimary),
        weekdayStyle: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600),
        rangePickerBackgroundColor: c.surface,
        rangeSelectionBackgroundColor: c.accent.withValues(alpha: 0.25),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.surface,
        hourMinuteColor: c.background,
        hourMinuteTextColor: c.textPrimary,
        dayPeriodColor: c.background,
        dayPeriodTextColor: c.textPrimary,
        dialBackgroundColor: c.background,
        dialTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.headerBottom : c.textPrimary,
        ),
        dialHandColor: c.accent,
        entryModeIconColor: c.textSecondary,
        helpTextStyle: TextStyle(color: c.textSecondary),
      ),
      extensions: [c],
    );
  }
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
