import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_links.dart';
import '../../../core/constants/support_contacts.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/web_launcher.dart';
import '../shared/app_snackbar.dart';

/// "قيّم التطبيق". The app is not on the store yet, so the sheet works without it:
///  * 4–5 stars → thank the person and offer to share the app (plus "rate on the store" once
///    [AppLinks.playStoreUrl] is set);
///  * 1–3 stars → ask what to improve and send it to support by WhatsApp or e-mail, so a
///    disappointed person reaches us instead of leaving a public review.
Future<void> showRateAppSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RateAppSheet(),
    );

class _RateAppSheet extends StatefulWidget {
  const _RateAppSheet();

  @override
  State<_RateAppSheet> createState() => _RateAppSheetState();
}

class _RateAppSheetState extends State<_RateAppSheet> {
  int _stars = 0;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _message(AppLocalizations l10n) => l10n.rateFeedbackMessage('$_stars', _note.text.trim());

  Future<void> _sendWhatsapp(AppLocalizations l10n) async {
    try {
      await launchWhatsAppChat(SupportContacts.whatsappNumber, _message(l10n));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, l10n.contactUsWhatsappFailedMessage);
    }
  }

  Future<void> _sendEmail(AppLocalizations l10n) async {
    try {
      await launchSupportEmail(email: SupportContacts.email, subject: l10n.rateEmailSubject, body: _message(l10n));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, l10n.contactUsEmailFailedMessage);
    }
  }

  Future<void> _share(AppLocalizations l10n) async {
    final language = Localizations.localeOf(context).languageCode;
    await SharePlus.instance.share(
      ShareParams(text: l10n.shareAppMessage(AppLinks.shareUrl(language)), subject: l10n.shareAppSubject),
    );
  }

  Future<void> _openStore(AppLocalizations l10n) async {
    final url = AppLinks.playStoreUrl;
    if (url == null) return;
    try {
      await launchWebPage(Uri.parse(url));
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, l10n.unexpectedError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final high = _stars >= 4;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.rateSheetTitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title(context).copyWith(color: shell.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.rateSheetSubtitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                ),
                const SizedBox(height: 14),
                // Stars are always laid out left→right as 1…5 whatever the language, so "tap the
                // 4th star" means the same in Arabic and English.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          iconSize: 38,
                          tooltip: '$i',
                          onPressed: () => setState(() => _stars = i),
                          icon: Icon(i <= _stars ? Icons.star_rounded : Icons.star_border_rounded, color: shell.accent),
                        ),
                    ],
                  ),
                ),
                if (_stars > 0) const SizedBox(height: 8),
                if (_stars > 0 && high) ...[
                  Text(
                    l10n.rateHighBody,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(context).copyWith(color: shell.textPrimary),
                  ),
                  const SizedBox(height: 14),
                  if (AppLinks.playStoreUrl != null) ...[
                    ElevatedButton.icon(
                      onPressed: () => unawaited(_openStore(l10n)),
                      style: ElevatedButton.styleFrom(backgroundColor: shell.accent, foregroundColor: shell.headerBottom),
                      icon: const Icon(Icons.star_rounded),
                      label: Text(l10n.rateStoreButton),
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_share(l10n)),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l10n.drawerShareApp),
                  ),
                ],
                if (_stars > 0 && !high) ...[
                  Text(
                    l10n.rateLowBody,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(context).copyWith(color: shell.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _note,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: InputDecoration(hintText: l10n.rateFeedbackHint, border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton.icon(
                    onPressed: () => unawaited(_sendWhatsapp(l10n)),
                    style: ElevatedButton.styleFrom(backgroundColor: shell.accent, foregroundColor: shell.headerBottom),
                    icon: const Icon(Icons.chat_outlined),
                    label: Text(l10n.rateSendWhatsapp),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_sendEmail(l10n)),
                    icon: const Icon(Icons.mail_outline),
                    label: Text(l10n.rateSendEmail),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
