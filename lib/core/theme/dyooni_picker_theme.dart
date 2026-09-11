import 'package:flutter/material.dart';
import 'app_shell_colors.dart';

/// Wraps a Material picker/dialog (pass as the `builder:` of [showDatePicker], etc.) so it uses
/// Dyooni's own [AppShellColors] instead of Flutter's default blue Material theme.
///
/// Uses [DatePickerThemeData] directly (not just `ColorScheme`) because the date picker needs
/// THREE different roles that a plain `ColorScheme` can't separate cleanly: the header bar
/// (navy), the calendar body background (white in light mode), and the selected-day highlight
/// (gold) — with a plain `ColorScheme.primary` the header and the selected-day circle would be
/// forced to the same color, which is exactly what this fixes.
///
/// - Light mode: navy header with gold header text, WHITE calendar body, BLACK day numbers,
///   and the selected day gets a solid GOLD circle (with dark navy text on it for contrast).
/// - Dark mode: same navy/gold roles, but the calendar body follows the dark shell's own surface
///   color instead of being forced white — a plain white panel would look out of place against
///   a dark screen.
///
/// The whole dialog is also wrapped in a slightly reduced [TextScaler] (0.92) — the standard way
/// to shrink Flutter's date picker, since it has no direct "size" parameter and lays itself out
/// from its own internal text metrics rather than the outer constraints.
Widget dyooniPickerTheme(BuildContext context, Widget? child) {
  final shell = context.shellColors;
  final base = Theme.of(context);
  final isDark = base.brightness == Brightness.dark;

  final bodyBackground = isDark ? shell.surface : Colors.white;
  final dayColor = isDark ? shell.textPrimary : Colors.black;
  final selectedDayText = shell.headerBottom;

  Color dayForeground(Set<WidgetState> states) =>
      states.contains(WidgetState.selected) ? selectedDayText : dayColor;
  Color dayBackground(Set<WidgetState> states) =>
      states.contains(WidgetState.selected) ? shell.accent : Colors.transparent;

  final themedDialog = Theme(
    data: base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: shell.accent,
        onPrimary: shell.headerBottom,
        surface: bodyBackground,
        onSurface: dayColor,
      ),
      dialogTheme: base.dialogTheme.copyWith(backgroundColor: bodyBackground),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: bodyBackground,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: shell.headerBottom,
        headerForegroundColor: shell.accent,
        weekdayStyle: TextStyle(color: dayColor.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
        dayForegroundColor: WidgetStateProperty.resolveWith(dayForeground),
        dayBackgroundColor: WidgetStateProperty.resolveWith(dayBackground),
        todayForegroundColor: WidgetStateProperty.resolveWith(dayForeground),
        todayBackgroundColor: WidgetStateProperty.resolveWith(dayBackground),
        todayBorder: BorderSide(color: shell.accent, width: 1.2),
        yearForegroundColor: WidgetStateProperty.resolveWith(dayForeground),
        yearBackgroundColor: WidgetStateProperty.resolveWith(dayBackground),
        rangePickerBackgroundColor: bodyBackground,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: shell.accent),
      ),
    ),
    child: child ?? const SizedBox.shrink(),
  );

  return MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.92)),
    child: themedDialog,
  );
}
