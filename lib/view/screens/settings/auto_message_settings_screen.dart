import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/account.dart';
import '../../../data/models/auto_message_settings.dart';
import '../../../data/models/currency_type.dart';
import '../../../data/models/transaction.dart';
import '../../../logic/currencies/currencies_provider.dart';
import '../../../logic/messages/auto_message_builder.dart';
import '../../../logic/messages/auto_message_provider.dart';
import '../../widgets/shared/app_screen_chrome.dart';

/// "إعدادات الرسائل التلقائية" (drawer → إشعارات الرصيد التلقائية).
///
/// Everything here feeds ONE pure function, [buildAutoMessage], and the live preview at the top
/// runs that same function on sample data — so what the person sees while editing is exactly
/// what will be sent. Each account can override the content/app (see
/// widgets/accounts/account_auto_message_dialog.dart).
class AutoMessageSettingsScreen extends ConsumerWidget {
  const AutoMessageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final s = ref.watch(autoMessageSettingsProvider);
    final ctl = ref.read(autoMessageSettingsProvider.notifier);
    final currencies = ref.watch(currencyTypesProvider);

    final sampleEntry = Transaction(
      id: 'sample',
      accountId: 'sample',
      amount: 5000,
      currency: 'YER',
      direction: AccountDirection.credit,
      date: DateTime.now(),
      details: l10n.autoSampleDetails,
    );
    final sampleEarlier = Transaction(
      id: 'sample0',
      accountId: 'sample',
      amount: 2000,
      currency: 'YER',
      direction: AccountDirection.credit,
      date: DateTime.now().subtract(const Duration(days: 3)),
    );
    final preview = buildAutoMessage(
      settings: s,
      texts: AutoMessageTexts.resolve(s, l10n),
      content: s.content,
      account: Account(id: 'sample', name: l10n.autoSampleName, category: AccountCategory.client, createdDate: DateTime.now()),
      entry: sampleEntry,
      accountTransactions: [sampleEarlier, sampleEntry],
      currencyNames: {'YER': currencyNameOf(currencies, 'YER')},
    );

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeaderBar(title: l10n.autoSettingsTitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: shell.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: shell.accent.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: shell.accent),
                        const SizedBox(width: 10),
                        Expanded(child: Text(l10n.autoIntroCard, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textPrimary))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionBar(l10n.autoPreviewTitle),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: shell.surface,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                      border: Border.all(color: shell.border),
                    ),
                    child: SelectableText(preview, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, height: 1.6)),
                  ),
                  const SizedBox(height: 16),
                  _SectionBar(l10n.autoSectionBehavior),
                  _SwitchRow(label: l10n.autoEnableTitle, value: s.enabled, onChanged: (v) => ctl.update((x) => x.copyWith(enabled: v))),
                  _SwitchRow(
                    label: l10n.autoSkipPreviewTitle,
                    subtitle: l10n.autoSkipPreviewSubtitle,
                    value: s.skipPreview,
                    onChanged: (v) => ctl.update((x) => x.copyWith(skipPreview: v)),
                  ),
                  _SwitchRow(label: l10n.autoShowDate, value: s.showDate, onChanged: (v) => ctl.update((x) => x.copyWith(showDate: v))),
                  _SwitchRow(
                    label: l10n.autoShowAllCurrencies,
                    value: s.showAllCurrencies,
                    onChanged: (v) => ctl.update((x) => x.copyWith(showAllCurrencies: v)),
                  ),
                  _ValueRow(
                    label: l10n.autoMinAmountTitle,
                    value: s.minAmount == 0 ? '0' : s.minAmount.toString(),
                    hint: l10n.autoMinAmountHint,
                    numeric: true,
                    onSaved: (text) {
                      final v = double.tryParse(text.trim().replaceAll(',', '')) ?? 0;
                      ctl.update((x) => x.copyWith(minAmount: v < 0 ? 0 : v));
                    },
                  ),
                  const SizedBox(height: 12),
                  _SectionBar(l10n.autoChannelTitle),
                  _ChoiceTile(l10n.autoChannelSms, s.channel == AutoMessageChannel.sms, () => ctl.update((x) => x.copyWith(channel: AutoMessageChannel.sms))),
                  _ChoiceTile(l10n.autoChannelWhatsapp, s.channel == AutoMessageChannel.whatsapp, () => ctl.update((x) => x.copyWith(channel: AutoMessageChannel.whatsapp))),
                  _ChoiceTile(l10n.autoChannelAsk, s.channel == AutoMessageChannel.ask, () => ctl.update((x) => x.copyWith(channel: AutoMessageChannel.ask))),
                  const SizedBox(height: 12),
                  _SectionBar(l10n.autoContentTitle),
                  _ChoiceTile(l10n.autoContentBalanceOnly, s.content == AutoMessageContent.balanceOnly, () => ctl.update((x) => x.copyWith(content: AutoMessageContent.balanceOnly))),
                  _ChoiceTile(l10n.autoContentDetailed, s.content == AutoMessageContent.detailed, () => ctl.update((x) => x.copyWith(content: AutoMessageContent.detailed))),
                  const SizedBox(height: 12),
                  _SectionBar(l10n.autoSectionTexts),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(l10n.autoTextsHint, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary)),
                  ),
                  _ValueRow(label: l10n.autoFieldIntro, value: s.intro, hint: l10n.autoDefaultIntro, onSaved: (t) => ctl.update((x) => x.copyWith(intro: t.trim()))),
                  _ValueRow(label: l10n.autoFieldBusiness, value: s.businessName, onSaved: (t) => ctl.update((x) => x.copyWith(businessName: t.trim()))),
                  _ValueRow(label: l10n.autoFieldHolderOwes, value: s.holderOwesText, hint: l10n.autoDefaultHolderOwes, onSaved: (t) => ctl.update((x) => x.copyWith(holderOwesText: t.trim()))),
                  _ValueRow(label: l10n.autoFieldOwedToHolder, value: s.owedToHolderText, hint: l10n.autoDefaultOwedToHolder, onSaved: (t) => ctl.update((x) => x.copyWith(owedToHolderText: t.trim()))),
                  _ValueRow(label: l10n.autoFieldTotalHolderOwes, value: s.totalHolderOwesText, hint: l10n.autoDefaultTotalHolderOwes, onSaved: (t) => ctl.update((x) => x.copyWith(totalHolderOwesText: t.trim()))),
                  _ValueRow(label: l10n.autoFieldTotalOwedToHolder, value: s.totalOwedToHolderText, hint: l10n.autoDefaultTotalOwedToHolder, onSaved: (t) => ctl.update((x) => x.copyWith(totalOwedToHolderText: t.trim()))),
                  _ValueRow(label: l10n.autoFieldHolderOwesNote, value: s.holderOwesNote, onSaved: (t) => ctl.update((x) => x.copyWith(holderOwesNote: t.trim()))),
                  _ValueRow(label: l10n.autoFieldSettledNote, value: s.settledNote, hint: l10n.autoDefaultSettled, onSaved: (t) => ctl.update((x) => x.copyWith(settledNote: t.trim()))),
                  _ValueRow(label: l10n.autoFieldDetailsPrefix, value: s.detailsPrefix, hint: l10n.autoDefaultDetailsPrefix, onSaved: (t) => ctl.update((x) => x.copyWith(detailsPrefix: t.trim()))),
                  _ValueRow(label: l10n.autoFieldFooter, value: s.footer, onSaved: (t) => ctl.update((x) => x.copyWith(footer: t.trim()))),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => ctl.update(
                      (x) => AutoMessageSettings(
                        enabled: x.enabled,
                        channel: x.channel,
                        content: x.content,
                        skipPreview: x.skipPreview,
                        showDate: x.showDate,
                        showAllCurrencies: x.showAllCurrencies,
                        minAmount: x.minAmount,
                      ),
                    ),
                    icon: const Icon(Icons.restore_rounded, color: AppColors.debit),
                    label: Text(l10n.autoResetTexts, style: const TextStyle(color: AppColors.debit)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionBar extends StatelessWidget {
  const _SectionBar(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(color: AppColors.backgroundTop, borderRadius: BorderRadius.circular(10)),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: AppTextStyles.body(context).copyWith(color: shell.accent, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged, this.subtitle});
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary)),
                if (subtitle != null)
                  Text(subtitle!, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(value: value, onChanged: onChanged, activeThumbColor: shell.accent),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? shell.accent : shell.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: selected ? FontWeight.w700 : FontWeight.w400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label with its current value (or the default as a faded hint) and a pencil that opens a
/// small edit dialog.
class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value, required this.onSaved, this.hint, this.numeric = false});
  final String label;
  final String value;
  final String? hint;
  final bool numeric;
  final ValueChanged<String> onSaved;

  Future<void> _edit(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final d = dialogContext.shellColors;
        return AlertDialog(
          backgroundColor: d.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(label, style: AppTextStyles.title(dialogContext).copyWith(color: d.textPrimary)),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l10n.cancel, style: TextStyle(color: d.textSecondary))),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(l10n.saveButton, style: TextStyle(color: d.accent, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result != null) onSaved(result);
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    final empty = value.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _edit(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: shell.border)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      empty ? (hint ?? '—') : value,
                      style: AppTextStyles.body(context).copyWith(color: empty ? shell.textSecondary.withValues(alpha: 0.6) : shell.textPrimary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_rounded, color: shell.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
