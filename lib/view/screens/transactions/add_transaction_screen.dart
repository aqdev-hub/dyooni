import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/currencies.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/account.dart';
import '../../../data/models/transaction.dart';
import '../../../logic/transactions/transactions_provider.dart';
import '../../widgets/shared/amount_in_words.dart';
import '../../widgets/shared/app_snackbar.dart';
import '../../widgets/shared/direction_choice.dart';
import '../../widgets/shared/labeled_field.dart';
import '../../widgets/shared/amount_calculator_dialog.dart';
import '../../widgets/shared/image_source_dialog.dart';
import '../../widgets/shared/modal_header_bar.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({required this.accountId, this.accountName, super.key});
  final String accountId;
  final String? accountName;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _detailsController = TextEditingController();

  String _currencyCode = currencies.first.code;
  DateTime _date = DateTime.now();
  AccountDirection _direction = AccountDirection.debit;
  bool _isSaving = false;
  String? _attachmentPath;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _chooseCurrency() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (final currency in currencies) ListTile(title: Text(currency.label(AppLocalizations.of(context)!)), onTap: () => Navigator.of(context).pop(currency.code))],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _currencyCode = selected);
  }

  Future<void> _openCalculator() async {
    final result = await showAmountCalculatorDialog(context, initialValue: _amountController.text);
    if (result != null && mounted) _amountController.text = result == result.roundToDouble() ? result.toInt().toString() : result.toString();
  }

  Future<void> _chooseImage() async {
    final image = await showImageSourceDialog(context);
    if (image != null && mounted) setState(() => _attachmentPath = image.path);
  }

  void _resetForm() {
    _amountController.clear();
    _detailsController.clear();
    setState(() {
      _date = DateTime.now();
      _direction = AccountDirection.debit;
    });
  }

  Future<void> _save({required bool keepAdding}) async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final transaction = Transaction(
      id: const Uuid().v4(),
      accountId: widget.accountId,
      amount: double.parse(_amountController.text.trim()),
      currency: _currencyCode,
      direction: _direction,
      date: _date,
      details: _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
      attachmentPath: _attachmentPath,
    );

    try {
      await ref.read(transactionsProvider.notifier).addTransaction(transaction);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, l10n.transactionSavedSuccessMessage);
      if (keepAdding) {
        _resetForm();
      } else {
        context.pop();
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(context, l10n.unexpectedError);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;

    return Scaffold(
      backgroundColor: shell.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ModalHeaderBar(title: l10n.addTransactionTitle, onClose: () => context.pop()),
                const SizedBox(height: 8),
                if (widget.accountName != null) ...[
                  LabeledField(
                    icon: Icons.person_outline_rounded,
                    child: Center(child: Text(widget.accountName!, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary))),
                  ),
                  const SizedBox(height: 6),
                ],
                LabeledField(
                  icon: Icons.calculate_outlined,
                  onIconTap: _openCalculator,
                  child: TextFormField(
                    controller: _amountController,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(hintText: l10n.amountLabel, border: InputBorder.none),
                    validator: (v) {
                      final parsed = double.tryParse((v ?? '').trim());
                      if (parsed == null || parsed <= 0) return l10n.invalidAmount;
                      return null;
                    },
                  ),
                ),
                AmountInWords(amountText: _amountController.text),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      l10n.currencyLabel,
                      style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(color: shell.headerBottom, borderRadius: BorderRadius.circular(5)),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit_rounded, size: 25, color: shell.accent),
                                onPressed: _chooseCurrency,
                              ),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _currencyCode,
                                    isExpanded: true,
                                    alignment: Alignment.center,
                                    style: AppTextStyles.body(context).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                                    items: [
                                      for (final c in currencies)
                                        DropdownMenuItem(
                                          value: c.code,
                                          alignment: Alignment.center,
                                          child: Text(c.label(l10n), textAlign: TextAlign.center),
                                        ),
                                    ],
                                    onChanged: (v) => setState(() => _currencyCode = v ?? _currencyCode),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 42),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LabeledField(
                  icon: Icons.calendar_today_outlined,
                  child: InkWell(
                    onTap: _pickDate,
                    child: Text(
                      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                      style: AppTextStyles.body(context).copyWith(color: shell.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LabeledField(
                  icon: Icons.camera_alt_outlined,
                  onIconTap: _chooseImage,
                  child: TextFormField(
                    controller: _detailsController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(hintText: l10n.detailsLabel, border: InputBorder.none),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DirectionChoice(
                      label: l10n.directionCredit,
                      color: AppColors.credit,
                      selected: _direction == AccountDirection.credit,
                      onTap: () => setState(() => _direction = AccountDirection.credit),
                    ),
                    const SizedBox(width: 24),
                    DirectionChoice(
                      label: l10n.directionDebit,
                      color: AppColors.debit,
                      selected: _direction == AccountDirection.debit,
                      onTap: () => setState(() => _direction = AccountDirection.debit),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Two save actions, matching the reference exactly: exit after saving, or save
                // and immediately start a fresh entry for the same account.
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () => _save(keepAdding: false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          side: const BorderSide(color: AppColors.backgroundTop),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          l10n.saveAndExit,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.button(context).copyWith(color: AppColors.backgroundTop),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : () => _save(keepAdding: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.backgroundTop,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                              )
                            : Text(
                                l10n.saveAndAddAnother,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.button(context).copyWith(color: Colors.white, fontSize: 13),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
