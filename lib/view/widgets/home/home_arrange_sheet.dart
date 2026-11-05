import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../logic/accounts/home_arrangement.dart';
import '../../../logic/settings/direction_labels.dart';
import '../../../logic/settings/general_settings_provider.dart';

/// The name of a sort option, as shown in the sheet and in Home's header.
String homeSortName(AppLocalizations l10n, HomeSort sort) => switch (sort) {
      HomeSort.newest => l10n.homeSortNameNewest,
      HomeSort.oldest => l10n.homeSortNameOldest,
      HomeSort.nameAsc => l10n.homeSortNameNameAsc,
      HomeSort.nameDesc => l10n.homeSortNameNameDesc,
      HomeSort.balanceDesc => l10n.homeSortNameBalanceDesc,
      HomeSort.balanceAsc => l10n.homeSortNameBalanceAsc,
      HomeSort.recentActivity => l10n.homeSortNameRecentActivity,
    };

/// Home's "ترتيب وتصفية": pick how the accounts are ordered and which balance states are shown.
/// Choices apply immediately (the list behind the sheet updates as you tap).
Future<void> showHomeArrangeSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ArrangeSheet(),
    );

class _ArrangeSheet extends ConsumerWidget {
  const _ArrangeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final sort = ref.watch(homeSortProvider);
    final status = ref.watch(homeStatusFilterProvider);
    final settings = ref.watch(generalSettingsProvider).value;
    final creditLabel = resolveCreditLabel(l10n, settings);
    final debitLabel = resolveDebitLabel(l10n, settings);

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(text, style: AppTextStyles.body(context).copyWith(color: shell.accent, fontWeight: FontWeight.w800)),
        );

    Widget chip(String label, HomeStatusFilter value) {
      final selected = status == value;
      return ChoiceChip(
        label: Text(label, style: TextStyle(color: selected ? shell.headerBottom : shell.textPrimary, fontWeight: FontWeight.w700)),
        selected: selected,
        selectedColor: shell.accent,
        backgroundColor: shell.surface,
        side: BorderSide(color: selected ? shell.accent : shell.border),
        showCheckmark: false,
        onSelected: (_) => ref.read(homeStatusFilterProvider.notifier).state = value,
      );
    }

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(16)),
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.homeArrangeTitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title(context).copyWith(color: shell.textPrimary),
                ),
                heading(l10n.homeSortSectionTitle),
                for (final option in HomeSort.values)
                  InkWell(
                    onTap: () => ref.read(homeSortProvider.notifier).state = option,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          Icon(
                            sort == option ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: sort == option ? shell.accent : shell.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              homeSortName(l10n, option),
                              style: AppTextStyles.body(context).copyWith(
                                color: shell.textPrimary,
                                fontWeight: sort == option ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                heading(l10n.homeFilterSectionTitle),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    chip(l10n.homeFilterAll, HomeStatusFilter.all),
                    chip(creditLabel, HomeStatusFilter.credit),
                    chip(debitLabel, HomeStatusFilter.debit),
                    chip(l10n.homeFilterSettled, HomeStatusFilter.settled),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isHomeArrangementActive(sort, status)
                            ? () {
                                ref.read(homeSortProvider.notifier).state = HomeSort.newest;
                                ref.read(homeStatusFilterProvider.notifier).state = HomeStatusFilter.all;
                              }
                            : null,
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.debit, side: const BorderSide(color: AppColors.debit)),
                        child: Text(l10n.homeArrangeReset),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(backgroundColor: shell.accent, foregroundColor: shell.headerBottom),
                        child: Text(l10n.homeArrangeDone),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
