import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/phone_number.dart';
import '../../../data/models/account.dart';
import '../../../data/models/auto_message_settings.dart';
import '../../../data/models/currency_type.dart';
import '../../../data/models/transaction.dart';
import '../../../logic/accounts/accounts_provider.dart';
import '../../../logic/currencies/currencies_provider.dart';
import '../../../logic/messages/auto_message_builder.dart';
import '../../../logic/messages/auto_message_provider.dart';
import '../../../logic/transactions/transactions_provider.dart';
import '../shared/app_snackbar.dart';

/// Called right after a NEW entry was saved. When the automatic message applies to that
/// account (global switch / per-account override, phone number present, amount above the
/// minimum) it prepares the balance message and either shows it for a last look or — if the
/// person chose "no preview" and a fixed app — opens that app straight away.
///
/// It never throws: a failure here must not turn a successful save into an error.
Future<void> offerAutoMessage(BuildContext context, WidgetRef ref, Transaction entry) async {
  try {
    final settings = ref.read(autoMessageSettingsProvider);
    final override = ref.read(accountAutoMessagesProvider)[entry.accountId];
    final effective = resolveAutoMessage(settings, override);
    if (!effective.active || !passesMinAmount(settings, entry)) return;

    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    final matches = accounts.where((a) => a.id == entry.accountId);
    if (matches.isEmpty) return;
    final account = matches.first;
    final l10n = AppLocalizations.of(context)!;

    final phone = normalizePhoneForMessaging(account.phone ?? '');
    if (phone == null) {
      AppSnackBar.showError(context, l10n.autoPromptNoPhone);
      return;
    }

    // The balance must include the entry just saved; add it if the stream has not delivered it.
    final all = ref.read(transactionsProvider).value ?? const <Transaction>[];
    final mine = all.where((t) => t.accountId == entry.accountId).toList();
    if (!mine.any((t) => t.id == entry.id)) mine.add(entry);

    final currencies = ref.read(currencyTypesProvider);
    final names = {for (final t in mine) t.currency: currencyNameOf(currencies, t.currency)};

    final text = buildAutoMessage(
      settings: settings,
      texts: AutoMessageTexts.resolve(settings, l10n),
      content: effective.content,
      account: account,
      entry: entry,
      accountTransactions: mine,
      currencyNames: names,
    );

    if (settings.skipPreview && effective.channel != AutoMessageChannel.ask) {
      await _send(context, l10n, phone: phone, text: text, whatsapp: effective.channel == AutoMessageChannel.whatsapp);
      return;
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PromptSheet(account: account, phone: phone, initialText: text, channel: effective.channel),
    );
  } catch (_) {
    // Intentionally silent — see the doc comment.
  }
}

Future<void> _send(BuildContext context, AppLocalizations l10n, {required String phone, required String text, required bool whatsapp}) async {
  try {
    if (whatsapp) {
      await launchWhatsAppChat(phone, text);
    } else {
      await launchSmsComposer(phone: '+$phone', body: text);
    }
  } catch (_) {
    if (context.mounted) AppSnackBar.showError(context, l10n.autoSendFailed);
  }
}

class _PromptSheet extends StatefulWidget {
  const _PromptSheet({required this.account, required this.phone, required this.initialText, required this.channel});
  final Account account;
  final String phone;
  final String initialText;
  final AutoMessageChannel channel;

  @override
  State<_PromptSheet> createState() => _PromptSheetState();
}

class _PromptSheetState extends State<_PromptSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _go(AppLocalizations l10n, {required bool whatsapp}) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop();
    await _send(context, l10n, phone: widget.phone, text: text, whatsapp: whatsapp);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final ask = widget.channel == AutoMessageChannel.ask;
    final whatsappButton = ElevatedButton.icon(
      onPressed: () => unawaited(_go(l10n, whatsapp: true)),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.credit, foregroundColor: Colors.white),
      icon: const Icon(Icons.chat_outlined),
      label: Text(ask ? l10n.autoPromptSendWhatsapp : l10n.autoPromptSend),
    );
    final smsButton = ElevatedButton.icon(
      onPressed: () => unawaited(_go(l10n, whatsapp: false)),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.backgroundTop, foregroundColor: Colors.white),
      icon: const Icon(Icons.sms_outlined),
      label: Text(ask ? l10n.autoPromptSendSms : l10n.autoPromptSend),
    );

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
                  l10n.autoPromptTitle(widget.account.name),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title(context).copyWith(color: shell.textPrimary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  minLines: 5,
                  maxLines: 12,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                if (ask)
                  Row(children: [Expanded(child: whatsappButton), const SizedBox(width: 8), Expanded(child: smsButton)])
                else if (widget.channel == AutoMessageChannel.whatsapp)
                  whatsappButton
                else
                  smsButton,
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.autoPromptSkip, style: TextStyle(color: shell.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
