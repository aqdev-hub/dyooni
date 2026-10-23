import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/currency_type.dart';
import '../../../logic/currencies/currencies_provider.dart';
import '../../widgets/shared/app_snackbar.dart';

/// "إدارة العملات" — opened from the drawer's العملات. The person's own list of currencies
/// ("محلي", "أجنبي", "دولار" …): each row shows the currency's name and how many transactions
/// are recorded in it. What is added here is exactly what the currency picker offers when
/// adding an account or a transaction, and each currency is its own page on Home and on
/// Account Details (see logic/currencies/currencies_provider.dart).
class CurrenciesScreen extends ConsumerWidget {
  const CurrenciesScreen({super.key});

  Future<void> _openEditor(BuildContext context, {CurrencyType? existing}) {
    return showDialog<void>(
      context: context,
      builder: (_) => _CurrencyEditorDialog(existing: existing),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final currencies = ref.watch(currencyTypesProvider);
    final usage = ref.watch(currencyUsageProvider);

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
                      l10n.currenciesScreenTitle,
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
                itemCount: currencies.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final currency = currencies[index];
                  return _CurrencyRow(
                    name: currency.name,
                    count: usage[currency.id] ?? 0,
                    onTap: () => _openEditor(context, existing: currency),
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
        tooltip: l10n.currencyAddTitle,
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({required this.name, required this.count, required this.onTap});
  final String name;
  final int count;
  final VoidCallback onTap;

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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Add (when [existing] is null) or edit/delete one currency.
class _CurrencyEditorDialog extends ConsumerStatefulWidget {
  const _CurrencyEditorDialog({this.existing});
  final CurrencyType? existing;

  @override
  ConsumerState<_CurrencyEditorDialog> createState() => _CurrencyEditorDialogState();
}

class _CurrencyEditorDialogState extends ConsumerState<_CurrencyEditorDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.existing?.name ?? '');
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _nameErrorText(AppLocalizations l10n, CurrencyNameError error) => switch (error) {
        CurrencyNameError.empty => l10n.currencyNameRequired,
        CurrencyNameError.duplicate => l10n.currencyNameDuplicate,
      };

  Future<void> _save() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final store = ref.read(currencyTypesStoreProvider.notifier);
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
    } on CurrencyNameException catch (e) {
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
          content: Text(l10n.currencyDeleteConfirmBody, style: AppTextStyles.body(dialogContext).copyWith(color: dShell.textSecondary)),
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
      await ref.read(currencyTypesStoreProvider.notifier).delete(existing.id);
      navigator.pop();
    } on CurrencyDeleteException catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        e.reason == CurrencyDeleteBlock.protected ? l10n.currencyDeleteProtected : l10n.currencyDeleteInUse,
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
        existing == null ? l10n.currencyAddTitle : l10n.currencyEditTitle,
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
        decoration: InputDecoration(
          labelText: l10n.currencyNameLabel,
          errorText: _error,
          counterText: '',
        ),
      ),
      actions: [
        if (existing != null)
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
          child: Text(l10n.saveButton, style: TextStyle(color: shell.accent, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
