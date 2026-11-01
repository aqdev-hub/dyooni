import 'package:dyooni/data/models/account_reminder.dart';
import 'package:dyooni/logic/reminders/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

AccountReminder reminder(DateTime due, ReminderRepeat repeat, {bool enabled = true}) => AccountReminder(
      id: 'r',
      notificationBase: 1,
      accountId: 'a',
      firstDue: due,
      repeat: repeat,
      enabled: enabled,
    );

void main() {
  final now = DateTime(2026, 11, 1, 12);

  test('once: future date is returned, past date is not', () {
    expect(upcomingOccurrences(reminder(DateTime(2026, 11, 5, 9), ReminderRepeat.none), now), [DateTime(2026, 11, 5, 9)]);
    expect(upcomingOccurrences(reminder(DateTime(2026, 10, 5, 9), ReminderRepeat.none), now), isEmpty);
  });

  test('disabled reminders never fire', () {
    expect(upcomingOccurrences(reminder(DateTime(2026, 11, 5), ReminderRepeat.none, enabled: false), now), isEmpty);
  });

  test('weekly: continues from the first date, same weekday and time', () {
    final r = reminder(DateTime(2026, 10, 1, 9), ReminderRepeat.weekly); // a Thursday
    final next = upcomingOccurrences(r, now, count: 3);
    expect(next, [DateTime(2026, 11, 5, 9), DateTime(2026, 11, 12, 9), DateTime(2026, 11, 19, 9)]);
    expect(next.every((d) => d.weekday == DateTime.thursday), isTrue);
  });

  test('weekly: a start in the future is the first occurrence', () {
    final r = reminder(DateTime(2026, 11, 3, 9), ReminderRepeat.weekly);
    expect(upcomingOccurrences(r, now, count: 2).first, DateTime(2026, 11, 3, 9));
  });

  test('monthly: day 31 is clamped to the last day of shorter months', () {
    final r = reminder(DateTime(2026, 1, 31, 8), ReminderRepeat.monthly);
    final next = upcomingOccurrences(r, DateTime(2026, 1, 31, 9), count: 3);
    expect(next, [DateTime(2026, 2, 28, 8), DateTime(2026, 3, 31, 8), DateTime(2026, 4, 30, 8)]);
  });

  test('monthly: rolls over the year', () {
    final r = reminder(DateTime(2026, 11, 15, 8), ReminderRepeat.monthly);
    expect(upcomingOccurrences(r, now, count: 3), [DateTime(2026, 11, 15, 8), DateTime(2026, 12, 15, 8), DateTime(2027, 1, 15, 8)]);
  });

  test('json round trip', () {
    final r = reminder(DateTime(2026, 11, 5, 9), ReminderRepeat.weekly).copyWith(note: 'سداد');
    final back = AccountReminder.fromJson(r.toJson());
    expect(back.repeat, ReminderRepeat.weekly);
    expect(back.note, 'سداد');
    expect(back.firstDue, r.firstDue);
  });
}
