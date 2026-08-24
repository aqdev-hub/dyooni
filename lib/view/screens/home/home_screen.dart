import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../logic/accounts/accounts_provider.dart';
import '../../widgets/home/account_list_tile.dart';
import '../../widgets/home/app_drawer.dart';
import '../../widgets/home/bottom_summary_bar.dart';
import '../../widgets/shared/app_snackbar.dart';
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

  @override
  void initState() {
    super.initState();
    ref.read(selectedCategoryProvider.notifier).state = null;
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

    return Scaffold(
      backgroundColor: shell.background,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
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
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _openVoiceScreen(bluetoothMode: false),
                    onLongPress: () => _openVoiceScreen(bluetoothMode: true),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _voiceSheetOpen ? shell.accent : shell.headerBottom),
                      child: Icon(Icons.mic_none_rounded, size: 19, color: _voiceSheetOpen ? shell.headerBottom : shell.accent),
                    ),
                  ),
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
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: shell.accent),
                onSelected: (_) => AppSnackBar.showError(context, l10n.comingSoonMessage),
                itemBuilder: (context) => [PopupMenuItem(value: 'sort', child: Text(l10n.homeSortNewest))],
              ),
              IconButton(
                icon: Image.asset('assets/icons/header_document_reference.png', width: 27, height: 27),
                tooltip: l10n.reportsOpenTooltip,
                onPressed: () => context.push('/reports'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
