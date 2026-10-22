import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/category_type.dart';
import '../../../logic/categories/categories_provider.dart';
import '../../widgets/shared/app_snackbar.dart';

/// "إدارة التصنيفات" — opened from the drawer's التصنيفات. The person's own list of account
/// categories (عام، العملاء، الموردين، …). Each row shows the name, how many accounts are in it
/// ("عام" counts every account) and a switch that shows/hides that category's TAB on Home.
///
/// This list is the single source for every place that uses categories: Home's tabs, the
/// category choice when adding/editing an account, and the Reports filter.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _openEditor(BuildContext context, {CategoryType? existing}) {
    return showDialog<void>(context: context, builder: (_) => _CategoryEditorDialog(existing: existing));
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, CategoryType category, bool visible) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(categoryTypesStoreProvider.notifier).setVisible(category.id, visible);
    } on CategoryVisibilityException {
      if (context.mounted) AppSnackBar.showError(context, l10n.categoryKeepOneVisible);
    } catch (_) {
      if (context.mounted) AppSnackBar.showError(context, l10n.unexpectedError);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final categories = ref.watch(categoryTypesProvider);
    final usage = ref.watch(categoryUsageProvider);

    return Scaffold(
      backgroundColor: shell.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [shell.headerTop, shell.headerBottom],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l10n.categoriesScreenTitle,
                      style: AppTextStyles.title(context).copyWith(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return _CategoryRow(
                    name: category.name,
                    count: usage[category.id] ?? 0,
                    visible: category.visible,
                    onTap: () => _openEditor(context, existing: category),
                    onToggle: (value) => _toggle(context, ref, category, value),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: shell.accent,
        foregroundColor: Colors.white,
        tooltip: l10n.categoryAddTitle,
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.name,
    required this.count,
    required this.visible,
    required this.onTap,
    required this.onToggle,
  });
  final String name;
  final int count;
  final bool visible;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Material(
      color: shell.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 18, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: shell.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$count',
                style: AppTextStyles.title(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 16),
              Switch(
                value: visible,
                activeColor: shell.accent,
                onChanged: onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add (when [existing] is null) or rename/delete one category.
class _CategoryEditorDialog extends ConsumerStatefulWidget {
  const _CategoryEditorDialog({this.existing});
  final CategoryType? existing;

  @override
  ConsumerState<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends ConsumerState<_CategoryEditorDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.existing?.name ?? '');
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _nameErrorText(AppLocalizations l10n, CategoryNameError error) => switch (error) {
        CategoryNameError.empty => l10n.categoryNameRequired,
        CategoryNameError.duplicate => l10n.categoryNameDuplicate,
      };

  Future<void> _save() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final store = ref.read(categoryTypesStoreProvider.notifier);
    final existing = widget.existing;

    final error = store.validateName(_controller.text, excludeId: existing?.id);
    if (error != null) {
      setState(() => _error = _nameErrorText(l10n, error));
      return;
    }

    setState(() => _busy = true);
    try {
      if (existing == null) {
        await store.add(_controller.text);
      } else {
        await store.rename(existing.id, _controller.text);
      }
      if (mounted) Navigator.of(context).pop();
    } on CategoryNameException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _nameErrorText(l10n, e.error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBar.showError(context, l10n.unexpectedError);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null || _busy) return;
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dShell = dialogContext.shellColors;
        return AlertDialog(
          backgroundColor: dShell.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(l10n.delete, style: AppTextStyles.title(dialogContext).copyWith(color: dShell.textPrimary)),
          content: Text(l10n.categoryDeleteConfirmBody, style: AppTextStyles.body(dialogContext).copyWith(color: dShell.textSecondary)),
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
      await ref.read(categoryTypesStoreProvider.notifier).delete(existing.id);
      navigator.pop();
    } on CategoryDeleteException catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        switch (e.reason) {
          CategoryDeleteBlock.protected => l10n.categoryDeleteProtected,
          CategoryDeleteBlock.inUse => l10n.categoryDeleteInUse,
          CategoryDeleteBlock.lastOne => l10n.categoryDeleteLastOne,
        },
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(context, l10n.unexpectedError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final existing = widget.existing;

    return AlertDialog(
      backgroundColor: shell.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        existing == null ? l10n.categoryAddTitle : l10n.categoryEditTitle,
        style: AppTextStyles.title(context).copyWith(color: shell.textPrimary),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 24,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        style: AppTextStyles.body(context).copyWith(color: shell.textPrimary),
        decoration: InputDecoration(labelText: l10n.categoryNameLabel, errorText: _error, counterText: ''),
      ),
      actions: [
        if (existing != null && !existing.isGeneral)
          TextButton(
            onPressed: _busy ? null : _delete,
            child: Text(l10n.delete, style: const TextStyle(color: AppColors.debit, fontWeight: FontWeight.w700)),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel, style: TextStyle(color: shell.textSecondary)),
        ),
        TextButton(
          onPressed: _busy ? null : _save,
          child: Text(l10n.save, style: TextStyle(color: shell.accent, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
