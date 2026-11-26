import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../../logic/accounts/accounts_provider.dart';
import '../../../logic/auth/auth_provider.dart';
import '../../../logic/currencies/currencies_provider.dart';
import '../../../logic/transactions/transactions_provider.dart';
import '../../widgets/shared/app_popup.dart';
import '../../widgets/shared/app_screen_chrome.dart';
import '../../widgets/shared/app_snackbar.dart';

/// The signed-in person's profile: who they are (name, photo, e-mail, phone, how they sign in),
/// a short summary of their activity, account/security actions and shortcuts to their own data.
///
/// Reads only from [authProfileProvider] (never Firebase types) and from the app's existing
/// providers for the counts, so it has no storage of its own.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profile = ref.watch(authProfileProvider);
    final accounts = ref.watch(accountsProvider).value?.length ?? 0;
    final transactions = ref.watch(transactionsProvider).value?.length ?? 0;
    final currencies = ref.watch(currencyTypesProvider).length;

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeaderBar(title: l10n.profileTitle),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _IdentityCard(profile: profile),
                    const SizedBox(height: 18),
                    _SectionTitle(l10n.profileStatsTitle),
                    const SizedBox(height: 10),
                    _StatsGrid(
                      items: [
                        (Icons.groups_2_outlined, l10n.profileStatAccounts, '$accounts'),
                        (Icons.receipt_long_outlined, l10n.profileStatTransactions, '$transactions'),
                        (Icons.attach_money_outlined, l10n.profileStatCurrencies, '$currencies'),
                        (Icons.event_available_outlined, l10n.profileStatMemberSince, _formatDate(profile?.createdAt) ?? '—'),
                      ],
                    ),
                    if (profile != null) ...[
                      const SizedBox(height: 18),
                      _SectionTitle(l10n.profileSecurityTitle),
                      const SizedBox(height: 10),
                      _SecurityCard(profile: profile),
                    ],
                    const SizedBox(height: 18),
                    _SectionTitle(l10n.profileShortcutsTitle),
                    const SizedBox(height: 10),
                    _ShortcutsCard(items: [
                      (Icons.badge_outlined, l10n.drawerPersonalData, '/personal-data'),
                      (Icons.settings_outlined, l10n.drawerSettings, '/general-settings'),
                      (Icons.cloud_outlined, l10n.drawerGoogleBackup, '/drive-backup'),
                      (Icons.save_alt_outlined, l10n.drawerLocalBackup, '/local-backup'),
                    ]),
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context, ref, l10n),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.debit,
                        side: const BorderSide(color: AppColors.debit),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(l10n.drawerLogout, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _chevron(BuildContext context, Color color) => Icon(
      Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
      color: color,
    );

String? _formatDate(DateTime? d) {
  if (d == null) return null;
  final local = d.toLocal();
  return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
  final confirmed = await showAppPopup<bool>(
    context: context,
    builder: (dialogContext) {
      final shell = dialogContext.shellColors;
      return AppPopup(
        title: l10n.logoutConfirmTitle,
        icon: Icons.logout_rounded,
        child: Text(l10n.logoutConfirmBody, style: AppTextStyles.body(dialogContext).copyWith(color: shell.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel, style: TextStyle(color: shell.textSecondary)),
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
  try {
    await ref.read(authRepositoryProvider).signOut();
  } catch (_) {
    // Same rule as the drawer: whatever a provider's sign-out does, the person lands on login.
  }
  if (context.mounted) context.go('/login');
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: shell.accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text, style: AppTextStyles.title(context).copyWith(color: shell.textPrimary, fontSize: 15)),
      ],
    );
  }
}

BoxDecoration _cardDecoration(AppShellColors shell) => BoxDecoration(
      color: shell.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: shell.border),
    );

class _IdentityCard extends ConsumerWidget {
  const _IdentityCard({required this.profile});
  final AuthProfile? profile;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '؟';
    final first = String.fromCharCode(parts.first.runes.first);
    if (parts.length == 1) return first;
    return '$first${String.fromCharCode(parts[1].runes.first)}';
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final newName = await showAppPopup<String>(
      context: context,
      builder: (_) => _EditNameDialog(initial: profile?.displayName ?? ''),
    );
    if (newName == null || !context.mounted) return;
    try {
      await ref.read(authRepositoryProvider).updateDisplayName(newName);
      ref.read(authProfileRevisionProvider.notifier).state++;
      if (context.mounted) AppSnackBar.showSuccess(context, l10n.profileNameSaved);
    } catch (_) {
      if (context.mounted) AppSnackBar.showError(context, l10n.unexpectedError);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final p = profile;
    final name = (p?.displayName.isNotEmpty ?? false) ? p!.displayName : l10n.profileGuestName;
    final photo = p?.photoUrl;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
        ),
        border: Border.all(color: shell.accent.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 3),
              color: AppColors.backgroundBottom,
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: photo != null && photo.isNotEmpty
                ? Image.network(
                    photo,
                    width: 104,
                    height: 104,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _InitialsText(_initials(name)),
                  )
                : _InitialsText(_initials(name)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headline(context).copyWith(color: AppColors.textPrimary, fontSize: 20),
                ),
              ),
              if (p != null)
                IconButton(
                  tooltip: l10n.profileEditName,
                  onPressed: () => unawaited(_editName(context, ref)),
                  icon: const Icon(Icons.edit_outlined, color: AppColors.gold, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _InfoLine(icon: Icons.mail_outline_rounded, text: (p?.email.isNotEmpty ?? false) ? p!.email : l10n.profileEmailEmpty),
          const SizedBox(height: 6),
          _InfoLine(icon: Icons.phone_outlined, text: (p?.phone.isNotEmpty ?? false) ? p!.phone : l10n.profilePhoneEmpty),
        ],
      ),
    );
  }
}

class _InitialsText extends StatelessWidget {
  const _InitialsText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: AppColors.gold, fontSize: 36, fontWeight: FontWeight.w800));
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    // Always on the fixed navy banner, so these colors are fixed too (not theme-dependent).
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.gold),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textDirection: TextDirection.ltr,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initial});
  final String initial;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    return AppPopup(
      title: l10n.profileEditName,
      icon: Icons.edit_outlined,
      child: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          style: TextStyle(color: shell.textPrimary),
          decoration: InputDecoration(
            labelText: l10n.profileNameLabel,
            hintText: l10n.profileNameHint,
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? l10n.profileNameRequired : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel, style: TextStyle(color: shell.textSecondary)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(l10n.profileSave, style: TextStyle(color: shell.accent, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) Navigator.of(context).pop(_controller.text.trim());
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.items});
  final List<(IconData, String, String)> items;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.3,
      children: [
        for (final (icon, label, value) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: _cardDecoration(shell),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: shell.accent.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(icon, color: shell.accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(value, style: AppTextStyles.title(context).copyWith(color: shell.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SecurityCard extends ConsumerWidget {
  const _SecurityCard({required this.profile});
  final AuthProfile profile;

  String _method(AppLocalizations l10n) {
    if (profile.providers.contains('google.com')) return l10n.profileMethodGoogle;
    if (profile.providers.contains('facebook.com')) return l10n.profileMethodFacebook;
    return l10n.profileMethodPassword;
  }

  Future<void> _run(BuildContext context, Future<void> Function() action, String success) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await action();
      if (context.mounted) AppSnackBar.showSuccess(context, success);
    } catch (_) {
      if (context.mounted) AppSnackBar.showError(context, l10n.unexpectedError);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final repo = ref.read(authRepositoryProvider);
    final last = _formatDate(profile.lastSignInAt);

    Widget row(IconData icon, String title, {String? subtitle, Widget? trailing, VoidCallback? onTap}) => ListTile(
          onTap: onTap,
          leading: Icon(icon, color: shell.accent),
          title: Text(title, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w600)),
          subtitle: subtitle == null ? null : Text(subtitle, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 12)),
          trailing: trailing,
        );

    return Container(
      decoration: _cardDecoration(shell),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
        children: [
          row(Icons.login_rounded, l10n.profileSignInMethod, subtitle: _method(l10n)),
          if (last != null) ...[Divider(height: 1, color: shell.border), row(Icons.history_rounded, l10n.profileLastSignIn, subtitle: last)],
          if (profile.email.isNotEmpty) ...[
            Divider(height: 1, color: shell.border),
            row(
              profile.emailVerified ? Icons.verified_rounded : Icons.mark_email_unread_outlined,
              profile.emailVerified ? l10n.profileEmailVerified : l10n.profileEmailNotVerified,
              trailing: profile.emailVerified
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
                  : TextButton(
                      onPressed: () => unawaited(_run(context, repo.sendEmailVerification, l10n.profileVerificationSent)),
                      child: Text(l10n.profileSendVerification, style: TextStyle(color: shell.accent, fontWeight: FontWeight.w700)),
                    ),
            ),
          ],
          if (profile.usesPassword && profile.email.isNotEmpty) ...[
            Divider(height: 1, color: shell.border),
            row(
              Icons.lock_reset_rounded,
              l10n.profileChangePassword,
              subtitle: l10n.profileChangePasswordSub,
              trailing: _chevron(context, shell.textSecondary),
              onTap: () => unawaited(_run(context, () => repo.sendPasswordResetEmail(profile.email), l10n.profilePasswordResetSent)),
            ),
          ],
        ],
      ),
      ),
    );
  }
}

class _ShortcutsCard extends StatelessWidget {
  const _ShortcutsCard({required this.items});
  final List<(IconData, String, String)> items;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Container(
      decoration: _cardDecoration(shell),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: shell.border),
            ListTile(
              leading: Icon(items[i].$1, color: shell.accent),
              title: Text(items[i].$2, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w600)),
              trailing: _chevron(context, shell.textSecondary),
              onTap: () => unawaited(context.push(items[i].$3)),
            ),
          ],
        ],
      ),
      ),
    );
  }
}
