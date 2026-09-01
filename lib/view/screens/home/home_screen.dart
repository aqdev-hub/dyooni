import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/account.dart';
import '../../../logic/accounts/accounts_provider.dart';
import '../../../logic/settings/drive_backup_controller.dart';
import '../../widgets/home/account_list_tile.dart';
import '../../widgets/home/app_drawer.dart';
import '../../widgets/home/bottom_summary_bar.dart';
import '../../widgets/shared/app_snackbar.dart';
import '../../widgets/shared/entity_actions_sheet.dart';
import '../../widgets/shared/selection_toolbar.dart';
import '../accounts/add_account_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _voiceSheetOpen = false;

  Future<void> _openAddAccount() => showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: const SizedBox(
            width: 340,
            height: 540,
            child: ClipRRect(borderRadius: BorderRadius.all(Radius.circular(12)), child: AddAccountScreen()),
          ),
        ),
      );

  Future<void> _openVoiceScreen({required bool bluetoothMode}) async {
    setState(() => _voiceSheetOpen = true);
    await context.push('/voice', extra: bluetoothMode);
    if (mounted) setState(() => _voiceSheetOpen = false);
  }

  void _cancelSelection() {
    ref.read(accountSelectionModeProvider.notifier).state = false;
    ref.read(selectedAccountIdsProvider.notifier).state = {};
  }

  Future<void> _confirmDeleteAccounts(Set<String> ids, {required bool multiple}) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dShell = dialogContext.shellColors;
        return AlertDialog(
          backgroundColor: dShell.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(l10n.deleteAccountConfirmTitle, style: AppTextStyles.title(dialogContext).copyWith(color: dShell.textPrimary)),
          content: Text(
            multiple ? l10n.deleteSelectedAccountsConfirmBody : l10n.deleteAccountConfirmBody,
            style: AppTextStyles.body(dialogContext).copyWith(color: dShell.textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel, style: TextStyle(color: dShell.textSecondary))),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.delete, style: const TextStyle(color: AppColors.debit, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      for (final id in ids) {
        await ref.read(accountsProvider.notifier).deleteAccount(id);
      }
      _cancelSelection();
      if (!mounted) return;
      AppSnackBar.showSuccess(context, l10n.accountDeletedSuccessMessage);
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(context, l10n.unexpectedError);
    }
  }

  void _openEditAccount(Account account) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 340,
          height: 540,
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: AddAccountScreen(existingAccount: account),
          ),
        ),
      ),
    );
  }

  void _handleAccountAction(Account account, EntityAction action, List<Account> visibleAccounts) {
    final l10n = AppLocalizations.of(context)!;
    switch (action) {
      case EntityAction.edit:
        _openEditAccount(account);
      case EntityAction.share:
      case EntityAction.transfer:
        AppSnackBar.showError(context, l10n.comingSoonMessage);
      case EntityAction.delete:
        _confirmDeleteAccounts({account.id}, multiple: false);
      case EntityAction.selectAll:
        ref.read(accountSelectionModeProvider.notifier).state = true;
        ref.read(selectedAccountIdsProvider.notifier).state = visibleAccounts.map((a) => a.id).toSet();
      case EntityAction.select:
        // Handled inside AccountListTile itself — never reaches here.
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    ref.read(selectedCategoryProvider.notifier).state = null;
    // Opportunistic daily Drive-backup check — fires once per app session. Any failure here
    // (offline, no Google account connected, etc.) is ALSO independently swallowed inside
    // DriveBackupController.build() itself, but this extra try/catch is what stops a failure
    // from ever surfacing as an unhandled Future error in this screen's own zone.
    unawaited(_checkDriveBackupSilently());
  }

  Future<void> _checkDriveBackupSilently() async {
    try {
      await ref.read(driveBackupControllerProvider.future);
    } catch (_) {
      // See DriveBackupController's doc comment — a background Drive check must never surface
      // an error to the person.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final accountsAsync = ref.watch(accountsProvider);
    final categoryFiltered = ref.watch(filteredAccountsProvider);
    final summary = ref.watch(accountsSummaryProvider);
    final selectionMode = ref.watch(accountSelectionModeProvider);
    final selectedIds = ref.watch(selectedAccountIdsProvider);

    return Scaffold(
      backgroundColor: shell.background,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            if (selectionMode)
              SelectionToolbar(
                selectedCount: selectedIds.length,
                onCancel: _cancelSelection,
                onSelectAll: () => ref.read(selectedAccountIdsProvider.notifier).state = categoryFiltered.map((a) => a.id).toSet(),
                onEdit: selectedIds.length == 1
                    ? () {
                        final match = categoryFiltered.where((a) => a.id == selectedIds.first);
                        if (match.isEmpty) return;
                        _openEditAccount(match.first);
                      }
                    : null,
                onDelete: () => _confirmDeleteAccounts(selectedIds, multiple: selectedIds.length > 1),
              )
            else
              _Header(
                searchController: _searchController,
                onQueryChanged: (v) => setState(() => _query = v),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(
                children: [
                  Text(
                    '(${summary.count})',
                    style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.people_outline, size: 18, color: shell.accent),
                  const Spacer(),
                  Text(
                    l10n.homeSortNewest,
                    style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.sort_rounded, size: 18, color: shell.textSecondary),
                ],
              ),
            ),
            Expanded(
              child: accountsAsync.when(
                data: (_) {
                  final filtered = _query.isEmpty
                      ? categoryFiltered
                      : categoryFiltered.where((a) => a.name.contains(_query)).toList();

                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(accountsProvider.future),
                    child: filtered.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: Center(
                                  child: Text(
                                    l10n.homeEmptyAccounts,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                            children: [
                              for (final account in filtered.reversed)
                                AccountListTile(
                                  account: account,
                                  onTap: () => context.push('/account-details', extra: account),
                                  onLongPressAction: (action) => _handleAccountAction(account, action, filtered),
                                ),
                            ],
                          ),
                  );
                },
                loading: () => Center(child: CircularProgressIndicator(color: shell.accent)),
                error: (error, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    AppSnackBar.showError(context, l10n.unexpectedError);
                  });
                  return Center(
                    child: Text(l10n.unexpectedError, style: AppTextStyles.bodySecondary(context)),
                  );
                },
              ),
            ),
            BottomSummaryBar(totalCredit: summary.totalCredit, totalDebit: summary.totalDebit, onAdd: _openAddAccount, addTooltip: l10n.homeAddAccount),
            _HomeBottomNav(
              onVoice: () => _openVoiceScreen(bluetoothMode: false),
              onVoiceLongPress: () => _openVoiceScreen(bluetoothMode: true),
              voiceActive: _voiceSheetOpen,
              onReports: () => context.push('/reports'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.searchController, required this.onQueryChanged});

  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [shell.headerTop, shell.headerBottom],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Column(
        children: [
          Row(
            children: [
              Builder(builder: (context) => IconButton(icon: Icon(Icons.menu_rounded, color: shell.accent, size: 21), onPressed: () => Scaffold.of(context).openDrawer())),
              const SizedBox(width: 6),
              Text(l10n.homeTabGeneral, style: AppTextStyles.body(context).copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(19)),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: shell.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          onChanged: onQueryChanged,
                          textAlignVertical: TextAlignVertical.center,
                          style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textPrimary),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: l10n.homeSearchHint,
                            hintStyle: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Image.asset('assets/icons/header_document_reference.png', width: 27, height: 27),
                tooltip: l10n.reportsOpenTooltip,
                onPressed: () => context.push('/reports'),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: shell.accent),
                color: shell.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: shell.border)),
                onSelected: (_) => AppSnackBar.showError(context, l10n.comingSoonMessage),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'sort', child: Text(l10n.homeSortNewest, style: TextStyle(color: shell.textPrimary))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// New persistent bottom navigation, placed under BottomSummaryBar: Home / Voice / Reports, each
/// opening its own screen. "Home" is deliberately non-navigating and shown as the active tab —
/// there's no separate route to push to that isn't this very screen, so it behaves like the
/// current tab in any standard bottom-nav bar rather than being a dead tap target.
class _HomeBottomNav extends StatelessWidget {
  const _HomeBottomNav({
    required this.onVoice,
    required this.onVoiceLongPress,
    required this.voiceActive,
    required this.onReports,
  });

  final VoidCallback onVoice;
  final VoidCallback onVoiceLongPress;
  final bool voiceActive;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;

    return Container(
      decoration: BoxDecoration(
        color: shell.headerBottom,
        border: Border(top: BorderSide(color: shell.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(icon: Icons.home_rounded, label: l10n.navHome, active: true, onTap: () {}),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.mic_none_rounded,
              label: l10n.navVoice,
              active: voiceActive,
              onTap: onVoice,
              onLongPress: onVoiceLongPress,
            ),
          ),
          Expanded(
            child: _NavItem(icon: Icons.picture_as_pdf_outlined, label: l10n.reportsTitle, active: false, onTap: onReports),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap, this.onLongPress});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    final color = active ? shell.accent : Colors.white70;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.bodySecondary(context).copyWith(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
