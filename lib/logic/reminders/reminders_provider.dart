import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../data/local/reminders/reminders_local_datasource.dart';
import '../../data/models/account.dart';
import '../../data/models/account_reminder.dart';
import '../accounts/accounts_provider.dart';
import '../onboarding/onboarding_provider.dart' show sharedPreferencesProvider;
import 'reminder_notification_service.dart';

final remindersLocalDataSourceProvider = Provider<RemindersLocalDataSource>(
  (ref) => RemindersLocalDataSource(ref.watch(sharedPreferencesProvider)),
);

final reminderNotificationServiceProvider = Provider<ReminderNotificationService>((ref) => ReminderNotificationService());

/// An account id waiting to be opened because the person tapped its reminder notification.
final pendingNotificationAccountProvider = StateProvider<String?>((ref) => null);

final remindersProvider = NotifierProvider<RemindersController, List<AccountReminder>>(RemindersController.new);

/// Reminders of one account.
final accountRemindersProvider = Provider.family<List<AccountReminder>, String>(
  (ref, accountId) => [for (final r in ref.watch(remindersProvider)) if (r.accountId == accountId) r],
);

class RemindersController extends Notifier<List<AccountReminder>> {
  @override
  List<AccountReminder> build() => ref.watch(remindersLocalDataSourceProvider).get();

  Future<void> _persist() => ref.read(remindersLocalDataSourceProvider).save(state);

  Future<void> _schedule(AccountReminder reminder, AppLocalizations l10n) async {
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    final name = accounts.where((a) => a.id == reminder.accountId).map((a) => a.name).firstOrNull ?? '';
    final note = reminder.note?.trim();
    await ref.read(reminderNotificationServiceProvider).schedule(
          reminder: reminder,
          title: l10n.reminderNotifTitle(name),
          body: (note != null && note.isNotEmpty) ? note : l10n.reminderNotifBody,
          channelName: l10n.reminderChannelName,
          channelDescription: l10n.reminderChannelDescription,
        );
  }

  /// Creates and schedules a reminder. Returns `false` when the phone is not allowing
  /// notifications (the reminder is still saved, so it works as soon as they are turned on).
  Future<bool> add({
    required AccountReminder Function(int base, String id) build,
    required AppLocalizations l10n,
  }) async {
    final service = ref.read(reminderNotificationServiceProvider);
    final allowed = await service.requestPermission();
    final base = await ref.read(remindersLocalDataSourceProvider).nextBase();
    final reminder = build(base, const Uuid().v4());
    state = [...state, reminder];
    await _persist();
    await _schedule(reminder, l10n);
    return allowed;
  }

  Future<void> setEnabled(String id, bool enabled, AppLocalizations l10n) async {
    final index = state.indexWhere((r) => r.id == id);
    if (index < 0) return;
    final updated = state[index].copyWith(enabled: enabled);
    state = [...state]..[index] = updated;
    await _persist();
    if (enabled) {
      await _schedule(updated, l10n);
    } else {
      await ref.read(reminderNotificationServiceProvider).cancel(updated);
    }
  }

  Future<void> remove(String id) async {
    final target = state.where((r) => r.id == id).firstOrNull;
    if (target == null) return;
    await ref.read(reminderNotificationServiceProvider).cancel(target);
    state = [for (final r in state) if (r.id != id) r];
    await _persist();
  }

  /// Run at app start (and after accounts load): drops reminders of deleted accounts and
  /// re-schedules the rest, which tops up the window of future repeats and picks up renamed
  /// accounts.
  Future<void> syncAll(AppLocalizations l10n) async {
    final accountIds = {for (final a in ref.read(accountsProvider).value ?? const <Account>[]) a.id};
    if (accountIds.isEmpty) return; // accounts not loaded yet (or none) — never delete on a guess
    final service = ref.read(reminderNotificationServiceProvider);
    final kept = <AccountReminder>[];
    for (final r in state) {
      if (accountIds.contains(r.accountId)) {
        kept.add(r);
      } else {
        await service.cancel(r);
      }
    }
    if (kept.length != state.length) {
      state = kept;
      await _persist();
    }
    for (final r in kept) {
      await _schedule(r, l10n);
    }
  }
}
