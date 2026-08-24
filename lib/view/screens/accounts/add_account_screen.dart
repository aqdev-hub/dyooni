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
import '../../../logic/accounts/accounts_provider.dart';
import '../../../logic/transactions/transactions_provider.dart';
import '../../widgets/shared/amount_in_words.dart';
import '../../widgets/shared/app_snackbar.dart';
import '../../widgets/shared/direction_choice.dart';
import '../../widgets/shared/labeled_field.dart';
import '../../widgets/shared/amount_calculator_dialog.dart';
import '../../widgets/shared/image_source_dialog.dart';
import '../../widgets/shared/modal_header_bar.dart';

class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({super.key});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _detailsController = TextEditingController();
  final _phoneController = TextEditingController();

  String _currencyCode = currencies.first.code;
  DateTime _date = DateTime.now();
  AccountDirection _direction = AccountDirection.debit; // matches the reference's default selection
  AccountCategory _category = AccountCategory.client;
  bool _isSaving = false;
  String? _attachmentPath;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _detailsController.dispose();
    _phoneController.dispose();
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

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final accountId = const Uuid().v4();
    final account = Account(
      id: accountId,
      name: _nameController.text.trim(),
      category: _category,
      createdDate: _date,
      details: _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    );
    final firstTransaction = Transaction(
      id: const Uuid().v4(),
      accountId: accountId,
      amount: double.parse(_amountController.text.trim()),
      currency: _currencyCode,
      direction: _direction,
      date: _date,
      details: _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
      attachmentPath: _attachmentPath,
    );

    try {
      await ref.read(accountsProvider.notifier).addAccount(account);
      await ref.read(transactionsProvider.notifier).addTransaction(firstTransaction);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, l10n.accountSavedSuccessMessage);
      context.pop();
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
                ModalHeaderBar(title: l10n.addAccountTitle, onClose: () => context.pop()),
                const SizedBox(height: 8),
                LabeledField(
                  icon: Icons.person_outline_rounded,
                  child: TextFormField(
                    controller: _nameController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(hintText: l10n.accountNameLabel, border: InputBorder.none),
                    validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
                  ),
                ),
                const SizedBox(height: 6),
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
                const SizedBox(height: 12),
                LabeledField(
                  icon: Icons.person_outline_rounded,
                  child: TextFormField(
                    controller: _phoneController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(hintText: l10n.phoneLabel, border: InputBorder.none),
                  ),
                ),
                const SizedBox(height: 16),
                Text(l10n.categoryLabel, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _CategoryChoiceChip(
                        label: l10n.categoryClient,
                        selected: _category == AccountCategory.client,
                        onTap: () => setState(() => _category = AccountCategory.client),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CategoryChoiceChip(
                        label: l10n.categorySupplier,
                        selected: _category == AccountCategory.supplier,
                        onTap: () => setState(() => _category = AccountCategory.supplier),
                      ),
                    ),
                  ],
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
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
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
                      : Text(l10n.saveButton, style: AppTextStyles.button(context).copyWith(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChoiceChip extends StatelessWidget {
  const _CategoryChoiceChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? shell.accent.withValues(alpha: 0.1) : shell.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? shell.accent : shell.border, width: selected ? 1.6 : 1),
        ),
        child: Text(
          label,
          style: AppTextStyles.body(context).copyWith(
            color: selected ? shell.accent : shell.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
