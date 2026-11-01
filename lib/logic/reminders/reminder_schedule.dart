import '../../data/models/account_reminder.dart';

/// How many notification slots every reminder owns (ids `base * slots + k`).
const reminderSlots = 12;

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// The next [count] times [reminder] should fire after [now], oldest first (device local time).
///
/// Why several at once: Android only fires what was scheduled, so a weekly reminder for an app that
/// is not opened for a month would otherwise fire once and then go silent. Scheduling a window
/// ahead and topping it up whenever the app starts keeps repeats alive without any background
/// service.
///  * once    → its date, if still in the future;
///  * weekly  → the same weekday and clock time every 7 days;
///  * monthly → the same day of the month (clamped: the 31st becomes the 30th/28th when needed).
/// Wall-clock time is kept across daylight-saving changes (built from date parts, not by adding
/// 24-hour blocks).
List<DateTime> upcomingOccurrences(AccountReminder reminder, DateTime now, {int count = 8}) {
  if (!reminder.enabled || count <= 0) return const [];
  final start = reminder.firstDue;
  final out = <DateTime>[];

  switch (reminder.repeat) {
    case ReminderRepeat.none:
      if (start.isAfter(now)) out.add(start);
    case ReminderRepeat.weekly:
      var k = 0;
      if (!start.isAfter(now)) {
        k = (now.difference(start).inDays ~/ 7);
      }
      while (out.length < count) {
        final d = DateTime(start.year, start.month, start.day + 7 * k, start.hour, start.minute);
        if (d.isAfter(now)) out.add(d);
        k++;
        if (k > 100000) break;
      }
    case ReminderRepeat.monthly:
      var k = 0;
      while (out.length < count) {
        final monthIndex = start.month - 1 + k;
        final year = start.year + monthIndex ~/ 12;
        final month = monthIndex % 12 + 1;
        final day = start.day > _daysInMonth(year, month) ? _daysInMonth(year, month) : start.day;
        final d = DateTime(year, month, day, start.hour, start.minute);
        if (d.isAfter(now)) out.add(d);
        k++;
        if (k > 12000) break;
      }
  }
  return out;
}

/// Slots to schedule for a reminder (once = 1, weekly = 8, monthly = 6).
int slotsToSchedule(ReminderRepeat repeat) => switch (repeat) {
      ReminderRepeat.none => 1,
      ReminderRepeat.weekly => 8,
      ReminderRepeat.monthly => 6,
    };
