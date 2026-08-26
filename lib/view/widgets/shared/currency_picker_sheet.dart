import 'package:flutter/material.dart';

import '../../../core/constants/currencies.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// The ONE currency picker for the whole app. Previously tapping the currency FIELD opened
/// Flutter's own default [DropdownButton] menu, while tapping the pencil icon next to it opened
/// this bottom sheet instead — two different pickers, two different looks, for the same field.
/// Both call sites now call this single function, styled with Dyooni's shell colors for both
/// light and dark mode (see AppShellColors).
///
/// Deliberately width-constrained (max 300) and centered rather than stretching edge-to-edge —
/// a currency list this short doesn't need the full screen width, and letting it stretch was
/// what made the sheet feel oversized. Row heights are also denser than a default `ListTile`.
Future<String?> showCurrencyPickerSheet(BuildContext context, {required String selectedCode}) {
  final l10n = AppLocalizations.of(context)!;
  final shell = context.shellColors;

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Container(
            margin: const EdgeInsets.all(16),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(14)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: shell.headerBottom,
                  child: Text(
                    l10n.currencyLabel,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.button(context).copyWith(color: shell.accent, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                for (final currency in currencies)
                  ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -3),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    title: Text(
                      currency.label(l10n),
                      textAlign: TextAlign.end,
                      style: AppTextStyles.bodySecondary(context).copyWith(
                        color: shell.textPrimary,
                        fontWeight: currency.code == selectedCode ? FontWeight.w800 : FontWeight.w400,
                      ),
                    ),
                    trailing: Icon(
                      currency.code == selectedCode ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                      size: 18,
                      color: currency.code == selectedCode ? shell.accent : shell.textSecondary,
                    ),
                    onTap: () => Navigator.of(context).pop(currency.code),
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
