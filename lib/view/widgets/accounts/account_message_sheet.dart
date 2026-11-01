import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/phone_number.dart';
import '../../../data/models/account.dart';
import '../../../data/models/transaction.dart';
import '../../../logic/messages/message_log_provider.dart';
import '../../../logic/messages/message_templates.dart';
import '../../../logic/reports/tabular_report.dart' show ReportBuilders;
import '../../../logic/settings/direction_labels.dart';
import '../../../logic/settings/general_settings_provider.dart';
import '../shared/app_snackbar.dart';

/// The "الرسائل" button of Account Details: pick a ready-made message (reminder, request, thanks,
/// statement…), edit it if wanted, and send it to the account's phone by WhatsApp or SMS — or
/// copy it. Only templates that make sense for the current balance are offered (see
/// [templatesFor]), and the sheet remembers when each was last sent.
Future<void> showAccountMessageSheet(
  BuildContext context, {
  required Account account,
  required List<Transaction> transactions,
  required String currencyName,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MessageSheet(account: account, transactions: transactions, currencyName: currencyName),
    );

class _MessageSheet extends ConsumerStatefulWidget {
  const _MessageSheet({required this.account, required this.transactions, required this.currencyName});
  final Account account;
  final List<Transaction> transactions;
  final String currencyName;

  @override
  ConsumerState<_MessageSheet> createState() => _MessageSheetState();
}

class _MessageSheetState extends ConsumerState<_MessageSheet> {
  final _controller = TextEditingController();
  MessageTemplate? _selected;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(MessageTemplate template, AppLocalizations l10n) {
    final settings = ref.read(generalSettingsProvider).value;
    setState(() {
      _selected = template;
      _controller.text = buildMessage(
        l10n: l10n,
        template: template,
        account: widget.account,
        transactions: widget.transactions,
        currencyName: widget.currencyName,
        creditLabel: resolveCreditLabel(l10n, settings),
        debitLabel: resolveDebitLabel(l10n, settings),
      );
    });
  }

  Future<void> _send(AppLocalizations l10n, {required bool whatsapp}) async {
    final phone = normalizePhoneForMessaging(widget.account.phone ?? '');
    final text = _controller.text.trim();
    final template = _selected;
    if (phone == null || text.isEmpty || template == null) return;
    try {
      if (whatsapp) {
        await launchWhatsAppChat(phone, text);
      } else {
        await launchSmsComposer(phone: '+$phone', body: text);
      }
      await ref.read(messageLogProvider.notifier).record(widget.account.id, template);
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, l10n.messageSendFailed);
    }
  }

  Future<void> _copy(AppLocalizations l10n) async {
    await Clipboard.setData(ClipboardData(text: _controller.text));
    if (mounted) AppSnackBar.showSuccess(context, l10n.messageCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final log = ref.watch(messageLogProvider);
    final net = netOf(widget.transactions);
    final hasPhone = normalizePhoneForMessaging(widget.account.phone ?? '') != null;
    final templates = templatesFor(net);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.messageSheetTitle(widget.account.name),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title(context).copyWith(color: shell.textPrimary),
                ),
                const SizedBox(height: 12),
                if (!hasPhone) ...[
                  Icon(Icons.phone_disabled_outlined, size: 40, color: shell.textSecondary),
                  const SizedBox(height: 8),
                  Text(
                    l10n.messageNoPhoneTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.messageNoPhoneBody,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                  ),
                ] else ...[
                  Text(l10n.messageChooseTemplate, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary)),
                  const SizedBox(height: 8),
                  for (final template in templates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: () => _select(template, l10n),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _selected == template ? shell.accent : shell.border, width: _selected == template ? 1.6 : 1),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(templateTitle(l10n, template), style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700)),
                                    if (log[MessageLogController.keyFor(widget.account.id, template)] != null)
                                      Text(
                                        l10n.messageLastSent(ReportBuilders.formatDate(log[MessageLogController.keyFor(widget.account.id, template)]!)),
                                        style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                              if (_selected == template) Icon(Icons.check_circle, color: shell.accent),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_selected != null) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      minLines: 4,
                      maxLines: 9,
                      decoration: InputDecoration(helperText: l10n.messageEditHint, border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => unawaited(_send(l10n, whatsapp: true)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.credit, foregroundColor: Colors.white),
                            icon: const Icon(Icons.chat_outlined),
                            label: Text(l10n.messageSendWhatsapp),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => unawaited(_send(l10n, whatsapp: false)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.backgroundTop, foregroundColor: Colors.white),
                            icon: const Icon(Icons.sms_outlined),
                            label: Text(l10n.messageSendSms),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () => unawaited(_copy(l10n)),
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(l10n.messageCopy),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
