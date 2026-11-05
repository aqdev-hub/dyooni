import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/voice_palette.dart';
import '../../../data/models/account.dart';
import '../../../data/models/currency_type.dart';
import '../../../logic/accounts/accounts_provider.dart';
import '../../../logic/accounts/currency_accounts_provider.dart';
import '../../../logic/accounts/home_arrangement.dart';
import '../../../logic/transactions/transactions_provider.dart';
import '../../../data/models/transaction.dart';
import '../../../logic/categories/categories_provider.dart';
import '../../../data/models/category_type.dart';
import '../../../logic/currencies/currencies_provider.dart';
import '../../../logic/reminders/reminders_provider.dart';
import '../../../logic/settings/general_settings_provider.dart';
import '../../../logic/settings/drive_backup_controller.dart';
import '../../widgets/home/account_list_tile.dart';
import '../../widgets/shared/app_screen_chrome.dart';
import '../../widgets/shared/main_bottom_nav.dart';
import '../../widgets/home/app_drawer.dart';
import '../../widgets/home/bottom_summary_bar.dart';
import '../../widgets/home/home_arrange_sheet.dart';
import '../../../logic/updates/update_service.dart';
import '../../widgets/settings/update_dialog.dart';
import '../../widgets/shared/app_snackbar.dart';
import '../../widgets/shared/currency_picker_sheet.dart';
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

  Future<void> _openVoiceScreen({required bool bluetoothMode}) =>
      context.push<void>('/voice', extra: bluetoothMode);

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
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_checkForUpdate()));
  }

  /// Once-a-day "a new version exists" check; every failure is silent (offline is normal).
  Future<void> _checkForUpdate() async {
    try {
      final decision = await ref.read(updateServiceProvider).checkOnStartup();
      if (decision == null || !mounted) return;
      await showUpdateDialog(context, ref, decision);
    } catch (_) {}
  }

  Future<void> _checkDriveBackupSilently() async {
    try {
      await ref.read(driveBackupControllerProvider.future);
    } catch (_) {
      // See DriveBackupController's doc comment — a background Drive check must never surface
      // an error to the person.
    }
  }

  bool _remindersSynced = false;

  /// Once accounts are loaded: (1) top up the scheduled reminder notifications once per launch,
  /// (2) if a notification was tapped, open that account. The tap is kept pending until the
  /// accounts exist, so a cold start from a notification still lands on the right screen.
  void _onAccountsReady(List<Account> accounts) {
    if (!mounted) return;
    if (!_remindersSynced) {
      _remindersSynced = true;
      final l10n = AppLocalizations.of(context);
      if (l10n != null) {
        unawaited(ref.read(remindersProvider.notifier).syncAll(l10n).catchError((_) {}));
      }
    }
    final pending = ref.read(pendingNotificationAccountProvider);
    if (pending == null) return;
    final match = accounts.where((a) => a.id == pending);
    ref.read(pendingNotificationAccountProvider.notifier).state = null;
    if (match.isEmpty) return;
    unawaited(context.push('/account-details', extra: match.first));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// يرتّب الحسابات المرئية حسب استعلام البحث الحالي. عندما تكون "تثبيت قائمة الحسابات عند
  /// البحث" (GeneralSettings.pinMatchingAccountsOnSearch) مفعّلة، تبقى القائمة كاملة لكن
  /// المطابقات تُرفَع لأعلاها بدل إخفاء بقية الحسابات؛ عند تعطيلها يعود السلوك لتصفية اعتيادية
  /// (إخفاء غير المطابق) — انظر view/screens/settings/general_settings_screen.dart.
  List<Account> _visibleAccounts(List<Account> categoryFiltered, bool pinMatches) {
    if (_query.isEmpty) return categoryFiltered;
    final matches = categoryFiltered.where((a) => a.name.contains(_query)).toList();
    if (!pinMatches) return matches;
    final rest = categoryFiltered.where((a) => !a.name.contains(_query)).toList();
    return [...matches, ...rest];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final accountsAsync = ref.watch(accountsProvider);
    final categoryFiltered = ref.watch(currencyAccountsProvider);
    final summary = ref.watch(currencyAccountsSummaryProvider);
    final currencyId = ref.watch(effectiveCurrencyIdProvider);
    final categoryTypes = ref.watch(categoryTypesProvider);
    final categoryTabs = ref.watch(categoryTabsProvider);
    final activeCategory = ref.watch(effectiveCategoryProvider);
    final currencies = ref.watch(currencyTypesProvider);
    final currencyName = currencyNameOf(currencies, currencyId);
    final selectionMode = ref.watch(accountSelectionModeProvider);
    final selectedIds = ref.watch(selectedAccountIdsProvider);
    final pinMatches = ref.watch(generalSettingsProvider).value?.pinMatchingAccountsOnSearch ?? true;

    // Sort + balance-state filter (the sheet behind the "ترتيب" label and the 3-dot menu). The
    // search below then works on this arranged list.
    final sort = ref.watch(homeSortProvider);
    final statusFilter = ref.watch(homeStatusFilterProvider);
    final arrangementActive = isHomeArrangementActive(sort, statusFilter);
    final lastActivity = <String, DateTime>{};
    for (final t in ref.watch(transactionsProvider).value ?? const <Transaction>[]) {
      final seen = lastActivity[t.accountId];
      if (seen == null || t.date.isAfter(seen)) lastActivity[t.accountId] = t.date;
    }
    final arranged = arrangeAccounts(
      accounts: categoryFiltered,
      sort: sort,
      status: statusFilter,
      balanceOf: (a) => ref.watch(accountCurrencyBalanceProvider((accountId: a.id, currency: currencyId))),
      lastActivityOf: (a) => lastActivity[a.id],
    );

    ref.listen<AsyncValue<List<Account>>>(accountsProvider, (_, next) {
      final list = next.value;
      if (list != null) _onAccountsReady(list);
    });
    ref.listen<String?>(pendingNotificationAccountProvider, (_, next) {
      final list = ref.read(accountsProvider).value;
      if (next != null && list != null) _onAccountsReady(list);
    });

    return AppScaffold(
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
                title: categoryNameOf(categoryTypes, activeCategory?.id ?? generalCategoryId),
                searchController: _searchController,
                onQueryChanged: (v) => setState(() => _query = v),
              ),
            // One tab per VISIBLE category from "إدارة التصنيفات". Hidden when only one is visible.
            if (categoryTabs.length > 1)
              _CategoryTabs(
                tabs: [for (final t in categoryTabs) (id: t?.id ?? generalCategoryId, name: categoryNameOf(categoryTypes, t?.id ?? generalCategoryId))],
                activeId: activeCategory?.id ?? generalCategoryId,
                onSelect: (id) => ref.read(selectedCategoryProvider.notifier).state =
                    id == generalCategoryId ? null : AccountCategory(id),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(
                children: [
                  Text(
                    '(${arrangementActive ? arranged.length : summary.count})',
                    style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.people_outline, size: 18, color: shell.accent),
                  const SizedBox(width: 10),
                  // The currency page: Home lists only the accounts that have entries in this
                  // currency, with their figures in it. Tap to switch page.
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final selected = await showCurrencyPickerSheet(context, selectedCode: currencyId, options: currencies);
                      if (selected != null) ref.read(selectedCurrencyIdProvider.notifier).state = selected;
                    },
                    child: Tooltip(
                      message: l10n.currencySwitchTooltip,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: shell.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: shell.accent),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.attach_money_rounded, size: 16, color: shell.accent),
                            const SizedBox(width: 2),
                            Text(
                              currencyName,
                              style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => unawaited(showHomeArrangeSheet(context)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.homeSortPrefix(homeSortName(l10n, sort)),
                            style: AppTextStyles.bodySecondary(context).copyWith(color: arrangementActive ? shell.accent : shell.textSecondary),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.sort_rounded, size: 18, color: arrangementActive ? shell.accent : shell.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: accountsAsync.when(
                data: (_) {
                  final filtered = _visibleAccounts(arranged, pinMatches);

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
                                    currencyId == defaultCurrencyId ? l10n.homeEmptyAccounts : l10n.homeEmptyAccountsInCurrency,
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
                              for (final account in filtered)
                                AccountListTile(
                                  account: account,
                                  currencyId: currencyId,
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
            BottomSummaryBar(
              totalCredit: summary.totalCredit,
              totalDebit: summary.totalDebit,
              onAdd: _openAddAccount,
              addTooltip: l10n.homeAddAccount,
              currencyName: currencyName,
            ),
            MainBottomNav(
              activeTab: MainNavTab.home,
              onHome: () {},
              onVoice: () => _openVoiceScreen(bluetoothMode: false),
              onVoiceLongPress: () => _openVoiceScreen(bluetoothMode: true),
              onReports: () => context.push('/reports'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.tabs, required this.activeId, required this.onSelect});

  final List<({String id, String name})> tabs;
  final String activeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Container(
      height: 42,
      color: shell.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: tabs.length,
        itemBuilder: (context, i) {
          final tab = tabs[i];
          final active = tab.id == activeId;
          return InkWell(
            onTap: () => onSelect(tab.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: active ? shell.accent : Colors.transparent, width: 3)),
              ),
              child: Text(
                tab.name,
                style: AppTextStyles.body(context).copyWith(
                  color: active ? shell.accent : shell.textSecondary,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.searchController, required this.onQueryChanged});

  final String title;
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
              Builder(builder: (context) => IconButton(icon: Icon(Icons.menu_rounded, color: context.voicePalette.headerGold, size: 28), onPressed: () => Scaffold.of(context).openDrawer())),
              const SizedBox(width: 6),
              Text(title, style: AppTextStyles.title(context).copyWith(color: context.voicePalette.headerGold, fontWeight: FontWeight.w800)),
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
                onSelected: (_) => unawaited(showHomeArrangeSheet(context)),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'arrange', child: Text(l10n.homeArrangeTitle, style: TextStyle(color: shell.textPrimary))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
