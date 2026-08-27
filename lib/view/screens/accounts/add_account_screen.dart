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
import '../../../core/utils/contact_picker.dart';
import '../../../core/utils/image_rotate.dart';
import '../../../data/models/account.dart';
import '../../../data/models/transaction.dart';
import '../../../logic/accounts/accounts_provider.dart';
import '../../../logic/transactions/transactions_provider.dart';
import '../../widgets/shared/amount_in_words.dart';
import '../../widgets/shared/app_snackbar.dart';
import '../../widgets/shared/currency_picker_sheet.dart';
import '../../widgets/shared/direction_choice.dart';
import '../../widgets/shared/labeled_field.dart';
import '../../widgets/shared/amount_calculator_dialog.dart';
import '../../widgets/shared/attachment_preview.dart';
import '../../widgets/shared/image_source_dialog.dart';
import '../../widgets/shared/modal_header_bar.dart';

class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({this.existingAccount, super.key});

  /// When non-null, this screen behaves as an EDIT of that account instead of creating a new
  /// one: the name/date/details/phone/category fields are pre-filled from it, the title and save
  /// button switch to "تعديل الحساب"/"تعديل", the amount/currency/direction fields (which only
  /// ever apply to the account's FIRST transaction) are hidden, and saving calls `updateAccount`
  /// (same id) instead of creating a new account + a new first transaction. Reached from the
  /// 3-dot menu's "تعديل" on Account Details, and from the account long-press action sheet /
  /// selection toolbar's "تعديل" on Home — see EntityAction.
  final Account? existingAccount;

  bool get isEditing => existingAccount != null;

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
    final existing = widget.existingAccount;
    if (existing != null) {
      _nameController.text = existing.name;
      _category = existing.category;
      _date = existing.createdDate;
      _detailsController.text = existing.details ?? '';
      _phoneController.text = existing.phone ?? '';
    }
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

  /// Rotates the currently-attached photo 90° in place — see AttachmentPreview's doc comment.
  Future<void> _rotateAttachment() async {
    final path = _attachmentPath;
    if (path == null) return;
    try {
      await rotateImageFile90(path);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, AppLocalizations.of(context)!.unexpectedError);
    }
  }

  /// Person icon next to the NAME field: picks a device contact and fills BOTH the name and the
  /// phone field from it (per explicit request — picking a contact from either icon should never
  /// leave the phone half-filled).
  Future<void> _pickContactForName() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final contact = await pickDeviceContact();
      if (contact == null || !mounted) return; // person backed out of the picker
      final name = displayName(contact);
      final phone = firstPhoneNumber(contact);
      setState(() {
        if (name != null) _nameController.text = name;
        if (phone != null) _phoneController.text = phone;
      });
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, l10n.contactPickFailedMessage);
    }
  }

  /// Phone icon next to the PHONE field: picks a device contact and fills ONLY the phone field —
  /// deliberately leaves the name field untouched, since the person may already be editing a
  /// different/existing name here.
  Future<void> _pickContactForPhone() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final contact = await pickDeviceContact();
      if (contact == null || !mounted) return;
      final phone = firstPhoneNumber(contact);
      if (phone != null) setState(() => _phoneController.text = phone);
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, l10n.contactPickFailedMessage);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    if (widget.isEditing) {
      final updated = Account(
        id: widget.existingAccount!.id,
        name: _nameController.text.trim(),
        category: _category,
        createdDate: _date,
        details: _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      );
      try {
        await ref.read(accountsProvider.notifier).updateAccount(updated);
        if (!mounted) return;
        AppSnackBar.showSuccess(context, l10n.accountUpdatedSuccessMessage);
        context.pop();
      } catch (_) {
        if (!mounted) return;
        AppSnackBar.showError(context, l10n.unexpectedError);
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
      return;
    }

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
                ModalHeaderBar(
                  title: widget.isEditing ? l10n.editAccountTitle : l10n.addAccountTitle,
                  onClose: () => context.pop(),
                ),
                const SizedBox(height: 8),
                LabeledField(
                  icon: Icons.person_outline_rounded,
                  onIconTap: _pickContactForName,
                  child: TextFormField(
                    controller: _nameController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(hintText: l10n.accountNameLabel, border: InputBorder.none),
                    validator: (v) {
                      final trimmed = (v ?? '').trim();
                      if (trimmed.isEmpty) return l10n.fieldRequired;
                      // The account name must be composite (first + last, at minimum) — a single
                      // word is rejected. `split` on any run of whitespace then dropping empty
                      // pieces handles multiple spaces between words correctly.
                      final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
                      if (words.length < 2) return l10n.accountNameMustBeTwoWords;
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 6),
                // The amount/currency/direction trio only ever applies to the account's FIRST
                // transaction — meaningless when editing an account that already exists, so it's
                // hidden entirely in that mode rather than shown-but-ignored.
                if (!widget.isEditing) ...[
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
                ],
                LabeledField(
                  icon: Icons.calendar_today_outlined,
                  onIconTap: _pickDate,
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
                // Only meaningful while CREATING — this attachment belongs to the account's
                // first transaction, and editing an account never touches a transaction at all
                // (see the class doc comment on `existingAccount`).
                if (!widget.isEditing && _attachmentPath != null)
                  AttachmentPreview(
                    path: _attachmentPath!,
                    onEdit: _chooseImage,
                    onRotate: _rotateAttachment,
                    onDelete: () => setState(() => _attachmentPath = null),
                  ),
                const SizedBox(height: 12),
                LabeledField(
                  icon: Icons.phone_outlined,
                  onIconTap: _pickContactForPhone,
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
                if (!widget.isEditing)
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
                      : Text(
                          widget.isEditing ? l10n.edit : l10n.saveButton,
                          style: AppTextStyles.button(context).copyWith(color: Colors.white),
                        ),
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
