import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dyooni_picker_theme.dart';
import '../../../data/models/account.dart';
import '../../../data/models/currency_type.dart';
import '../../../data/models/transaction.dart';
import '../../../logic/accounts/accounts_provider.dart';
import '../../../logic/currencies/currencies_provider.dart';
import '../../../logic/reports/tabular_report.dart' show ReportBuilders;
import '../../../logic/settings/general_settings_provider.dart';
import '../../../logic/transactions/transactions_provider.dart';
import '../../../logic/transactions/transfer_logic.dart';
import '../../widgets/shared/amount_calculator_dialog.dart';
import '../../widgets/shared/amount_in_words.dart';
import '../../widgets/shared/app_screen_chrome.dart';
import '../../widgets/shared/app_snackbar.dart';
import '../../widgets/shared/currency_picker_sheet.dart';
import '../../widgets/shared/labeled_field.dart';
import '../../widgets/shared/validated_field.dart';

/// "تحويل": moves an amount between this account and another one. It saves TWO linked entries
/// (see [buildTransferLegs]) — a debit on the sender and a credit on the receiver — so both
/// accounts stay correct and the transfer can be removed from both at once.
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({required this.account, super.key});

  /// The account whose screen the button was pressed on.
  final Account account;

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _fromHere = true;
  Account? _other;
  late String _currency = ref.read(effectiveCurrencyIdProvider);
  DateTime _date = DateTime.now();
  String? _amountError;
  String? _accountError;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountController.text.trim());

  Future<void> _pickOther() async {
    final l10n = AppLocalizations.of(context)!;
    final accounts = (ref.read(accountsProvider).value ?? const <Account>[]).where((a) => a.id != widget.account.id).toList();
    if (accounts.isEmpty) {
      AppSnackBar.showError(context, l10n.transferNoOtherAccounts);
      return;
    }
    final picked = await showModalBottomSheet<Account>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountPickerSheet(accounts: accounts),
    );
    if (picked != null && mounted) {
      setState(() {
        _other = picked;
        _accountError = null;
      });
    }
  }

  Future<void> _pickCurrency() async {
    final selected = await showCurrencyPickerSheet(context, selectedCode: _currency, options: ref.read(currencyTypesProvider));
    if (selected != null && mounted) setState(() => _currency = selected);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: dyooniPickerTheme,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _openCalculator() async {
    final result = await showAmountCalculatorDialog(context, initialValue: _amountController.text);
    if (result != null && mounted) {
      setState(() => _amountController.text = result == result.roundToDouble() ? result.toInt().toString() : result.toString());
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final other = _other;
    final problem = validateTransfer(fromAccountId: widget.account.id, toAccountId: other?.id, amount: _amount);
    if (problem != null) {
      setState(() {
        _accountError = problem == TransferProblem.missingAccount
            ? l10n.transferChooseAccount
            : (problem == TransferProblem.sameAccount ? l10n.transferSameAccount : null);
        _amountError = problem == TransferProblem.invalidAmount ? l10n.invalidAmount : null;
      });
      return;
    }
    if (other == null) return;
    final from = _fromHere ? widget.account : other;
    final to = _fromHere ? other : widget.account;
    final note = _noteController.text.trim();
    String withNote(String base) => note.isEmpty ? base : '$base — $note';
    const uuid = Uuid();
    final legs = buildTransferLegs(
      transferId: uuid.v4(),
      debitEntryId: uuid.v4(),
      creditEntryId: uuid.v4(),
      fromAccountId: from.id,
      toAccountId: to.id,
      amount: _amount!,
      currency: _currency,
      date: _date,
      detailsForFrom: withNote(l10n.transferDetailsTo(to.name)),
      detailsForTo: withNote(l10n.transferDetailsFrom(from.name)),
    );
    setState(() => _saving = true);
    try {
      await ref.read(transactionsProvider.notifier).addTransfer(legs);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, l10n.transferSuccess);
      context.pop();
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, l10n.unexpectedError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final settings = ref.watch(generalSettingsProvider).value;
    final showWords = settings?.showAmountInWordsWhileTyping ?? true;
    final currencyName = currencyNameOf(ref.watch(currencyTypesProvider), _currency);
    final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
    final other = _other;
    final amount = _amount;
    final canPreview = other != null && amount != null && amount > 0;

    Widget previewCard() {
      final from = _fromHere ? widget.account : other!;
      final to = _fromHere ? other! : widget.account;
      final value = amount!;
      final fromAfter = balanceAfter(transactions: transactions, accountId: from.id, currency: _currency, delta: -value);
      final toAfter = balanceAfter(transactions: transactions, accountId: to.id, currency: _currency, delta: value);
      String money(double v) => '${ReportBuilders.formatAmount(v)} $currencyName';
      String signedMoney(double v) => v < 0 ? '${money(v)} -' : money(v);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: shell.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: shell.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.transferPreviewTitle, style: AppTextStyles.title(context).copyWith(color: shell.textPrimary, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              l10n.transferPreviewDebit(from.name, money(value), signedMoney(fromAfter)),
              style: AppTextStyles.body(context).copyWith(color: AppColors.debit),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.transferPreviewCredit(to.name, money(value), signedMoney(toAfter)),
              style: AppTextStyles.body(context).copyWith(color: AppColors.credit),
            ),
          ],
        ),
      );
    }

    Widget directionChip(String label, bool selected, VoidCallback onTap) => Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.backgroundTop : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? AppColors.gold : shell.border, width: selected ? 1.4 : 1),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.button(context).copyWith(color: selected ? AppColors.gold : shell.textPrimary, fontSize: 13),
              ),
            ),
          ),
        );

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeaderBar(title: l10n.transferTitle),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LabeledField(
                      icon: Icons.person_outline_rounded,
                      child: Center(
                        child: Text(
                          '${l10n.transferThisAccount}: ${widget.account.name}',
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        directionChip(l10n.transferFromHere, _fromHere, () => setState(() => _fromHere = true)),
                        const SizedBox(width: 10),
                        directionChip(l10n.transferToHere, !_fromHere, () => setState(() => _fromHere = false)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ValidatedField(
                      icon: Icons.swap_horiz_rounded,
                      errorText: _accountError,
                      onIconTap: _pickOther,
                      child: InkWell(
                        onTap: () => unawaited(_pickOther()),
                        child: SizedBox(
                          width: double.infinity,
                          child: Center(
                            child: Text(
                              other?.name ?? l10n.transferChooseAccount,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body(context).copyWith(color: other == null ? shell.textSecondary : shell.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ValidatedField(
                      icon: Icons.calculate_outlined,
                      onIconTap: _openCalculator,
                      errorText: _amountError,
                      child: TextFormField(
                        controller: _amountController,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() => _amountError = null),
                        decoration: InputDecoration(hintText: l10n.amountLabel, border: InputBorder.none),
                      ),
                    ),
                    if (showWords) AmountInWords(amountText: _amountController.text),
                    const SizedBox(height: 12),
                    LabeledField(
                      icon: Icons.edit_rounded,
                      onIconTap: _pickCurrency,
                      child: InkWell(
                        onTap: () => unawaited(_pickCurrency()),
                        child: SizedBox(
                          width: double.infinity,
                          child: Center(
                            child: Text('${l10n.currencyLabel}: $currencyName', style: AppTextStyles.body(context).copyWith(color: shell.textPrimary)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    LabeledField(
                      icon: Icons.calendar_today_outlined,
                      onIconTap: _pickDate,
                      child: InkWell(
                        onTap: () => unawaited(_pickDate()),
                        child: SizedBox(
                          width: double.infinity,
                          child: Center(
                            child: Text(
                              '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                              style: AppTextStyles.body(context).copyWith(color: shell.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    LabeledField(
                      icon: Icons.notes_rounded,
                      child: TextFormField(
                        controller: _noteController,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(hintText: l10n.transferNoteHint, border: InputBorder.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (canPreview) previewCard(),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.backgroundTop,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : Text(l10n.transferSave, style: AppTextStyles.button(context).copyWith(color: Colors.white)),
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

/// Searchable list of the accounts a transfer can go to/from.
class _AccountPickerSheet extends StatefulWidget {
  const _AccountPickerSheet({required this.accounts});
  final List<Account> accounts;

  @override
  State<_AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<_AccountPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty ? widget.accounts : widget.accounts.where((a) => a.name.toLowerCase().contains(q)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: l10n.transferSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: shown.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: Icon(Icons.person_outline_rounded, color: shell.textSecondary),
                    title: Text(shown[i].name, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary)),
                    onTap: () => Navigator.of(context).pop(shown[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
