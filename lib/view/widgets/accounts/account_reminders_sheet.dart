import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dyooni_picker_theme.dart';
import '../../../data/models/account.dart';
import '../../../data/models/account_reminder.dart';
import '../../../logic/reminders/reminder_schedule.dart';
import '../../../logic/reminders/reminders_provider.dart';
import '../shared/app_snackbar.dart';

/// The "التنبيه" button of Account Details: payment-date reminders for ONE account, delivered as
/// phone notifications (also while the app is closed). Tapping the notification opens the account.
Future<void> showAccountRemindersSheet(BuildContext context, {required Account account}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RemindersSheet(account: account),
    );

String _two(int v) => v.toString().padLeft(2, '0');
String _formatWhen(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}  ${_two(d.hour)}:${_two(d.minute)}';

class _RemindersSheet extends ConsumerStatefulWidget {
  const _RemindersSheet({required this.account});
  final Account account;

  @override
  ConsumerState<_RemindersSheet> createState() => _RemindersSheetState();
}

class _RemindersSheetState extends ConsumerState<_RemindersSheet> {
  bool _adding = false;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  ReminderRepeat _repeat = ReminderRepeat.none;
  final _note = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  DateTime get _due => DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
      builder: dyooniPickerTheme,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time, builder: dyooniPickerTheme);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _save(AppLocalizations l10n) async {
    if (!_due.isAfter(DateTime.now())) {
      setState(() => _error = l10n.reminderPastTime);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final note = _note.text.trim();
      final allowed = await ref.read(remindersProvider.notifier).add(
            l10n: l10n,
            build: (base, id) => AccountReminder(
              id: id,
              notificationBase: base,
              accountId: widget.account.id,
              firstDue: _due,
              repeat: _repeat,
              note: note.isEmpty ? null : note,
            ),
          );
      if (!mounted) return;
      setState(() {
        _adding = false;
        _note.clear();
        _repeat = ReminderRepeat.none;
      });
      if (allowed) {
        AppSnackBar.showSuccess(context, l10n.reminderSaved);
      } else {
        AppSnackBar.showError(context, l10n.reminderPermissionDenied);
      }
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, l10n.unexpectedError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(AppLocalizations l10n, AccountReminder reminder) async {
    final shell = context.shellColors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: shell.surface,
        title: Text(l10n.reminderDeleteConfirm, style: AppTextStyles.title(dialogContext).copyWith(color: shell.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel, style: TextStyle(color: shell.textSecondary))),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete, style: const TextStyle(color: AppColors.debit, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(remindersProvider.notifier).remove(reminder.id);
    if (mounted) AppSnackBar.showSuccess(context, l10n.reminderDeleted);
  }

  String _repeatLabel(AppLocalizations l10n, ReminderRepeat r) => switch (r) {
        ReminderRepeat.none => l10n.reminderRepeatNone,
        ReminderRepeat.weekly => l10n.reminderRepeatWeekly,
        ReminderRepeat.monthly => l10n.reminderRepeatMonthly,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final reminders = [...ref.watch(accountRemindersProvider(widget.account.id))];
    final now = DateTime.now();
    DateTime? nextOf(AccountReminder r) => upcomingOccurrences(r, now, count: 1).firstOrNull;
    reminders.sort((a, b) => (nextOf(a) ?? DateTime(2100)).compareTo(nextOf(b) ?? DateTime(2100)));

    Widget pickerBox(IconData icon, String text, VoidCallback onTap) => Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: shell.border)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: shell.accent),
                  const SizedBox(width: 8),
                  Text(text, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary)),
                ],
              ),
            ),
          ),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${l10n.reminderSheetTitle} — ${widget.account.name}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title(context).copyWith(color: shell.textPrimary),
                ),
                const SizedBox(height: 12),
                if (!_adding) ...[
                  if (reminders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        l10n.reminderEmpty,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                      ),
                    ),
                  for (final r in reminders)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: shell.border)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nextOf(r) != null ? l10n.reminderNext(_formatWhen(nextOf(r)!)) : (r.enabled ? l10n.reminderFinished : _formatWhen(r.firstDue)),
                                  style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  [_repeatLabel(l10n, r.repeat), if ((r.note ?? '').isNotEmpty) r.note!].join(' • '),
                                  style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: r.enabled,
                            onChanged: (v) => unawaited(ref.read(remindersProvider.notifier).setEnabled(r.id, v, l10n)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.debit),
                            onPressed: () => unawaited(_confirmDelete(l10n, r)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _adding = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.backgroundTop,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.add_alarm_rounded),
                    label: Text(l10n.reminderAdd),
                  ),
                ] else ...[
                  Row(
                    children: [
                      pickerBox(Icons.calendar_today_outlined, '${_date.year}-${_two(_date.month)}-${_two(_date.day)}', () => unawaited(_pickDate())),
                      const SizedBox(width: 8),
                      pickerBox(Icons.access_time_rounded, '${_two(_time.hour)}:${_two(_time.minute)}', () => unawaited(_pickTime())),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.reminderRepeatLabel, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final r in ReminderRepeat.values)
                        ChoiceChip(
                          label: Text(_repeatLabel(l10n, r)),
                          selected: _repeat == r,
                          selectedColor: shell.accent,
                          onSelected: (_) => setState(() => _repeat = r),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _note,
                    maxLength: 120,
                    decoration: InputDecoration(hintText: l10n.reminderNoteHint, border: const OutlineInputBorder(), isDense: true),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => setState(() => _adding = false),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          child: Text(l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : () => unawaited(_save(l10n)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.backgroundTop,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: _saving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                              : Text(l10n.reminderSave),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
