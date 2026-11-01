import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/phone_number.dart';
import '../../../data/models/account.dart';
import '../../../data/models/auto_message_settings.dart';
import '../../../logic/messages/auto_message_provider.dart';

/// The per-account automatic-message dialog (3-dot menu → إعدادات الرسائل التلقائية). Two
/// plain choices — what the message says and which app sends it — each with "use the global
/// default", saved with one button.
Future<void> showAccountAutoMessageDialog(BuildContext context, {required Account account}) => showDialog<void>(
      context: context,
      builder: (_) => _AccountAutoDialog(account: account),
    );

class _AccountAutoDialog extends ConsumerStatefulWidget {
  const _AccountAutoDialog({required this.account});
  final Account account;

  @override
  ConsumerState<_AccountAutoDialog> createState() => _AccountAutoDialogState();
}

class _AccountAutoDialogState extends ConsumerState<_AccountAutoDialog> {
  late AccountAutoMode _mode;
  late AccountAutoChannel _channel;

  @override
  void initState() {
    super.initState();
    final current = ref.read(accountAutoMessagesProvider)[widget.account.id] ?? const AccountAutoMessage();
    _mode = current.mode;
    _channel = current.channel;
  }

  Widget _option<T>(BuildContext context, String label, T value, T group, ValueChanged<T> onTap) {
    final shell = context.shellColors;
    final selected = value == group;
    return InkWell(
      onTap: () => onTap(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? shell.accent : shell.textSecondary, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final hasPhone = normalizePhoneForMessaging(widget.account.phone ?? '') != null;

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(text, style: AppTextStyles.body(context).copyWith(color: shell.accent, fontWeight: FontWeight.w800)),
        );

    return AlertDialog(
      backgroundColor: shell.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(l10n.autoAccountTitle(widget.account.name), style: AppTextStyles.title(context).copyWith(color: shell.textPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hasPhone)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: shell.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(l10n.autoAccountNoPhone, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textPrimary)),
              ),
            heading(l10n.autoAccountTypeTitle),
            _option(context, l10n.autoAccountBalanceOnly, AccountAutoMode.balanceOnly, _mode, (v) => setState(() => _mode = v)),
            _option(context, l10n.autoAccountDetailed, AccountAutoMode.detailed, _mode, (v) => setState(() => _mode = v)),
            _option(context, l10n.autoAccountDefault, AccountAutoMode.useDefault, _mode, (v) => setState(() => _mode = v)),
            _option(context, l10n.autoAccountOff, AccountAutoMode.off, _mode, (v) => setState(() => _mode = v)),
            const Divider(height: 20),
            heading(l10n.autoAccountChannelTitle),
            _option(context, l10n.autoChannelSms, AccountAutoChannel.sms, _channel, (v) => setState(() => _channel = v)),
            _option(context, l10n.autoChannelWhatsapp, AccountAutoChannel.whatsapp, _channel, (v) => setState(() => _channel = v)),
            _option(context, l10n.autoChannelAsk, AccountAutoChannel.ask, _channel, (v) => setState(() => _channel = v)),
            _option(context, l10n.autoAccountDefault, AccountAutoChannel.useDefault, _channel, (v) => setState(() => _channel = v)),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/auto-messages');
              },
              child: Text(l10n.autoAccountOpenGlobal, style: TextStyle(color: shell.accent)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel, style: TextStyle(color: shell.textSecondary))),
        TextButton(
          onPressed: () async {
            await ref.read(accountAutoMessagesProvider.notifier).setFor(widget.account.id, AccountAutoMessage(mode: _mode, channel: _channel));
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(l10n.saveButton, style: TextStyle(color: shell.accent, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
