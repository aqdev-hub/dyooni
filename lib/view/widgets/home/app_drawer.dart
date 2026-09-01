import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../logic/auth/auth_provider.dart';
import '../shared/app_logo.dart';
import '../shared/app_snackbar.dart';
import '../shared/language_toggle_button.dart';
import '../shared/theme_toggle_button.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        // Styled explicitly with the shell's own colors — previously this AlertDialog had NO
        // color styling at all, which is exactly what made the title/body text unreadable: it
        // silently inherited whatever the ambient Material default happened to be for the
        // current brightness instead of Dyooni's own navy/gold identity.
        final dShell = dialogContext.shellColors;
        return AlertDialog(
          backgroundColor: dShell.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(l10n.logoutConfirmTitle, style: AppTextStyles.title(dialogContext).copyWith(color: dShell.textPrimary)),
          content: Text(l10n.logoutConfirmBody, style: AppTextStyles.body(dialogContext).copyWith(color: dShell.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel, style: TextStyle(color: dShell.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.drawerLogout, style: const TextStyle(color: AppColors.debit, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // See AuthRepositoryImpl.signOut's doc comment for the full story on why this try/catch is
    // here — the short version: whatever happens inside signOut(), the person who just confirmed
    // "log out" always lands on the login screen immediately, not after a manual app restart.
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      // Intentionally swallowed — Firebase's own auth state is the actual source of truth here,
      // and we still navigate below regardless of what happened in the other sign-out calls.
    }
    if (context.mounted) context.go('/login');
  }

  void _showComingSoon(BuildContext context, AppLocalizations l10n) {
    AppSnackBar.showError(context, l10n.comingSoonMessage);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;

    // (icon, label, route) — route is null for the items that are still honest "coming soon"
    // placeholders. "حفظ/استرجاع البيانات من جوجل" AND "مزامنة البيانات على جوجل درايف" now
    // BOTH point at the same real Drive-backup screen: the approved design brief for this
    // feature explicitly rejects a separate live "sync" concept ("Google Drive ليس Mirror
    // لحظيًا لـ Firestore") — a second menu entry implementing something different there would
    // just be a confusing dead end pointing at a feature that was deliberately never built.
    final items = <(IconData, String, String?)>[
      (Icons.workspace_premium_outlined, l10n.drawerAdsRemoval, null),
      (Icons.chat_outlined, l10n.drawerContactUs, null),
      (Icons.card_giftcard_outlined, l10n.drawerFreePoints, null),
      (Icons.person_outline, l10n.drawerPersonalData, '/personal-data'),
      (Icons.settings_outlined, l10n.drawerSettings, null),
      (Icons.notifications_active_outlined, l10n.drawerAutoBalanceAlerts, null),
      (Icons.category_outlined, l10n.drawerCategories, null),
      (Icons.attach_money_outlined, l10n.drawerCurrencies, null),
      (Icons.save_alt_outlined, l10n.drawerLocalBackup, '/local-backup'),
      (Icons.cloud_outlined, l10n.drawerGoogleBackup, '/drive-backup'),
      (Icons.sync_outlined, l10n.drawerGoogleDriveSync, '/drive-backup'),
      (Icons.dns_outlined, l10n.drawerSendDatabase, null),
      (Icons.share_outlined, l10n.drawerShareApp, null),
      (Icons.star_outline, l10n.drawerRateApp, null),
      (Icons.privacy_tip_outlined, l10n.drawerPrivacyPolicy, null),
      (Icons.support_agent_outlined, l10n.drawerSupport, null),
    ];

    return Drawer(
      backgroundColor: shell.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Fixed navy dark→light gradient — this banner always uses AppColors.backgroundTop /
            // backgroundBottom (the app's one approved navy pair) regardless of the light/dark
            // shell toggle below it, per explicit direction: no other colors here.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppLogo(size: 80),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Text(
                          l10n.appName,
                          style: AppTextStyles.headline(context).copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LanguageToggleButton(color: AppColors.gold),
                      ThemeToggleButton(color: AppColors.gold),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: shell.border, height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final (icon, label, route) in items)
                    ListTile(
                      leading: Icon(icon, color: shell.textSecondary, size: 20),
                      title: Text(label, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textPrimary)),
                      onTap: () => route != null ? context.push(route) : _showComingSoon(context, l10n),
                    ),
                ],
              ),
            ),
            Divider(color: shell.border, height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.debit, size: 20),
              title: Text(l10n.drawerLogout, style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.debit, fontWeight: FontWeight.w600)),
              onTap: () => _confirmLogout(context, ref, l10n),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
