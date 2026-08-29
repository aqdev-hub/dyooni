import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/currencies.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dyooni_picker_theme.dart';
import '../../../core/utils/image_rotate.dart';
import '../../../data/models/account.dart';
import '../../../data/models/transaction.dart';
import '../../../logic/transactions/transactions_provider.dart';
import '../../widgets/shared/amount_in_words.dart';
import '../../widgets/shared/app_snackbar.dart';
import '../../widgets/shared/direction_choice.dart';
import '../../widgets/shared/labeled_field.dart';
import '../../widgets/shared/amount_calculator_dialog.dart';
import '../../widgets/shared/attachment_preview.dart';
import '../../widgets/shared/currency_picker_sheet.dart';
import '../../widgets/shared/image_source_dialog.dart';
import '../../widgets/shared/modal_header_bar.dart';
import '../../widgets/shared/validated_field.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({required this.accountId, this.accountName, this.existingTransaction, super.key});
  final String accountId;
  final String? accountName;

  /// When non-null, this screen behaves as an EDIT of that transaction instead of adding a new
  /// one: fields are pre-filled, the title/buttons switch to "تعديل عملية" + تعديل/حذف, and
  /// saving calls `updateTransaction` (same id) instead of `addTransaction`. Reached by tapping
  /// a transaction row, or "تعديل" from its long-press action sheet — see transaction_table.dart.
  final Transaction? existingTransaction;

  bool get isEditing => existingTransaction != null;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _detailsController = TextEditingController();

  String _currencyCode = currencies.first.code;
  DateTime _date = DateTime.now();
  AccountDirection _direction = AccountDirection.debit;
  bool _isSaving = false;
  bool _isRotating = false;
  String? _attachmentPath;

  // Validated manually (not via Form/TextFormField.validator) — see ValidatedField's doc comment
  // for the layout bug (error text overflowing the field's fixed-height box) that caused.
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
    final existing = widget.existingTransaction;
    if (existing != null) {
      _amountController.text = existing.amount == existing.amount.roundToDouble()
          ? existing.amount.toInt().toString()
          : existing.amount.toString();
      _detailsController.text = existing.details ?? '';
      _currencyCode = existing.currency;
      _date = existing.date;
      _direction = existing.direction;
      _attachmentPath = existing.attachmentPath;
    }
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
      builder: dyooniPickerTheme,
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// Reached identically from the currency field itself and from its pencil icon — see
  /// currency_picker_sheet.dart's doc comment for why these used to be two different pickers.
  Future<void> _chooseCurrency() async {
    final selected = await showCurrencyPickerSheet(context, selectedCode: _currencyCode);
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

  /// Rotates the currently-attached photo 90° in place. The file path never changes — see
  /// AttachmentPreview's doc comment for how the thumbnail still picks up the new bytes.
  /// `_isRotating` disables the attachment's buttons and shows a spinner over the thumbnail while
  /// the background isolate works, so the button never again looks like it "did nothing".
  Future<void> _rotateAttachment() async {
    final path = _attachmentPath;
    if (path == null || _isRotating) return;
    setState(() => _isRotating = true);
    try {
      await rotateImageFile90(path);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, AppLocalizations.of(context)!.unexpectedError);
    } finally {
      if (mounted) setState(() => _isRotating = false);
    }
  }

  void _resetForm() {
    _amountController.clear();
    _detailsController.clear();
    setState(() {
      _date = DateTime.now();
      _direction = AccountDirection.debit;
      _amountError = null;
    });
  }

  Transaction _buildTransaction() {
    final existing = widget.existingTransaction;
    return Transaction(
      id: existing?.id ?? const Uuid().v4(),
      accountId: widget.accountId,
      amount: double.parse(_amountController.text.trim()),
      currency: _currencyCode,
      direction: _direction,
      date: _date,
      details: _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
      attachmentPath: _attachmentPath,
      voiceRecording: existing?.voiceRecording,
    );
  }

  String? _validateAmount(AppLocalizations l10n) {
    final parsed = double.tryParse(_amountController.text.trim());
    if (parsed == null || parsed <= 0) return l10n.invalidAmount;
    return null;
  }

  Future<void> _save({required bool keepAdding}) async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    final amountError = _validateAmount(l10n);
    setState(() => _amountError = amountError);
    if (amountError != null) return;

    setState(() => _isSaving = true);
    final transaction = _buildTransaction();

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

  Future<void> _update() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    final amountError = _validateAmount(l10n);
    setState(() => _amountError = amountError);
    if (amountError != null) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(transactionsProvider.notifier).updateTransaction(_buildTransaction());
      if (!mounted) return;
      AppSnackBar.showSuccess(context, l10n.transactionUpdatedSuccessMessage);
      context.pop();
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(context, l10n.unexpectedError);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final existing = widget.existingTransaction;
    if (existing == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dShell = dialogContext.shellColors;
        return AlertDialog(
          backgroundColor: dShell.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(l10n.deleteTransactionConfirmTitle, style: AppTextStyles.title(dialogContext).copyWith(color: dShell.textPrimary)),
          content: Text(l10n.deleteTransactionConfirmBody, style: AppTextStyles.body(dialogContext).copyWith(color: dShell.textSecondary)),
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

    setState(() => _isSaving = true);
    try {
      await ref.read(transactionsProvider.notifier).deleteTransaction(existing.id);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, l10n.transactionDeletedSuccessMessage);
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
    final isEditing = widget.isEditing;

    return Scaffold(
      backgroundColor: shell.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ModalHeaderBar(
                title: isEditing ? l10n.editTransactionTitle : l10n.addTransactionTitle,
                onClose: () => context.pop(),
              ),
              const SizedBox(height: 8),
              if (widget.accountName != null) ...[
                LabeledField(
                  icon: Icons.person_outline_rounded,
                  child: Center(child: Text(widget.accountName!, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary))),
                ),
                const SizedBox(height: 6),
              ],
              ValidatedField(
                icon: Icons.calculate_outlined,
                onIconTap: _openCalculator,
                errorText: _amountError,
                child: TextFormField(
                  controller: _amountController,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) {
                    if (_amountError != null) setState(() => _amountError = null);
                  },
                  decoration: InputDecoration(hintText: l10n.amountLabel, border: InputBorder.none),
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
                              // Tapping the field itself now opens the SAME picker as the pencil
                              // icon (see currency_picker_sheet.dart) — previously this was a
                              // native DropdownButton, a second, differently-styled picker.
                              child: InkWell(
                                onTap: _chooseCurrency,
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    currencies.firstWhere((c) => c.code == _currencyCode).label(l10n),
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.body(context).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                                  ),
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
                onIconTap: _pickDate,
                child: InkWell(
                  onTap: _pickDate,
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
                icon: Icons.camera_alt_outlined,
                onIconTap: _chooseImage,
                child: TextFormField(
                  controller: _detailsController,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(hintText: l10n.detailsLabel, border: InputBorder.none),
                ),
              ),
              if (_attachmentPath != null)
                AttachmentPreview(
                  path: _attachmentPath!,
                  isBusy: _isRotating,
                  onEdit: _chooseImage,
                  onRotate: _rotateAttachment,
                  onDelete: () => setState(() => _attachmentPath = null),
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
              if (isEditing)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _delete,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          side: const BorderSide(color: AppColors.debit),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          l10n.delete,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.button(context).copyWith(color: AppColors.debit),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _update,
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
                                l10n.edit,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.button(context).copyWith(color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                )
              else
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
    );
  }
}
