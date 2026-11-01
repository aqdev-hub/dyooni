enum ReminderRepeat { none, weekly, monthly }

/// A payment-date reminder for one account. Stored on THIS device only (a notification belongs
/// to the phone that shows it), so it is not part of the cloud/backup data.
class AccountReminder {
  const AccountReminder({
    required this.id,
    required this.notificationBase,
    required this.accountId,
    required this.firstDue,
    required this.repeat,
    this.note,
    this.enabled = true,
  });

  final String id;

  /// A small unique number: this reminder's notifications use ids `base * slots + 0..slots-1`
  /// (several future occurrences are scheduled at once — see reminder_schedule.dart).
  final int notificationBase;
  final String accountId;

  /// The first date/time it fires (device local time). Repeats continue from it.
  final DateTime firstDue;
  final ReminderRepeat repeat;
  final String? note;
  final bool enabled;

  AccountReminder copyWith({DateTime? firstDue, ReminderRepeat? repeat, String? note, bool? enabled, bool clearNote = false}) =>
      AccountReminder(
        id: id,
        notificationBase: notificationBase,
        accountId: accountId,
        firstDue: firstDue ?? this.firstDue,
        repeat: repeat ?? this.repeat,
        note: clearNote ? null : (note ?? this.note),
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'notificationBase': notificationBase,
        'accountId': accountId,
        'firstDue': firstDue.toIso8601String(),
        'repeat': repeat.name,
        'note': note,
        'enabled': enabled,
      };

  factory AccountReminder.fromJson(Map<String, dynamic> json) => AccountReminder(
        id: json['id'] as String,
        notificationBase: (json['notificationBase'] as num).toInt(),
        accountId: json['accountId'] as String,
        firstDue: DateTime.parse(json['firstDue'] as String),
        repeat: ReminderRepeat.values.firstWhere((r) => r.name == json['repeat'], orElse: () => ReminderRepeat.none),
        note: json['note'] as String?,
        enabled: json['enabled'] as bool? ?? true,
      );
}
