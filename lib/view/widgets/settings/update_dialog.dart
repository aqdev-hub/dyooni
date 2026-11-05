import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_links.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/web_launcher.dart';
import '../../../logic/updates/app_update.dart';
import '../../../logic/updates/update_service.dart';

/// "يتوفر تحديث جديد": the new version, what it brings, "تحديث الآن" and (unless the update is
/// mandatory) "لاحقًا". A mandatory update can't be dismissed by back or by tapping outside.
Future<void> showUpdateDialog(BuildContext context, WidgetRef ref, UpdateDecision decision) async {
  final release = decision.release;
  if (release == null) return;
  final forced = decision.kind == UpdateKind.required;
  final l10n = AppLocalizations.of(context)!;
  final shell = context.shellColors;
  final notes = release.notesFor(Localizations.localeOf(context).languageCode);

  await showDialog<void>(
    context: context,
    barrierDismissible: !forced,
    builder: (ctx) => PopScope(
      canPop: !forced,
      child: AlertDialog(
        backgroundColor: shell.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.system_update_alt_rounded, color: shell.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(l10n.updateAvailableTitle, style: AppTextStyles.title(ctx).copyWith(color: shell.textPrimary))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.updateNewVersion('${release.version} (${release.build})'),
                  style: AppTextStyles.body(ctx).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w800)),
              if (forced) ...[
                const SizedBox(height: 6),
                Text(l10n.updateRequiredNote, style: AppTextStyles.bodySecondary(ctx).copyWith(color: shell.textSecondary)),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.updateWhatsNew, style: AppTextStyles.bodySecondary(ctx).copyWith(color: shell.textSecondary)),
                const SizedBox(height: 6),
                for (final n in notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: shell.accent, fontWeight: FontWeight.w900)),
                        Expanded(child: Text(n, style: AppTextStyles.body(ctx).copyWith(color: shell.textPrimary))),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          if (!forced)
            TextButton(
              onPressed: () {
                ref.read(updateServiceProvider).dismiss(release);
                Navigator.of(ctx).pop();
              },
              child: Text(l10n.updateLater, style: TextStyle(color: shell.textSecondary)),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: shell.accent, foregroundColor: shell.headerBottom),
            onPressed: () async {
              try {
                await launchWebPage(Uri.parse(release.url ?? AppLinks.shareUrl('ar')));
              } catch (_) {}
            },
            child: Text(l10n.updateNow, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    ),
  );
}
