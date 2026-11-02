import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/account_reminder.dart';
import 'reminder_schedule.dart';

/// Thin wrapper over `flutter_local_notifications` for payment reminders. Everything that decides
/// WHEN to fire lives in reminder_schedule.dart (pure, tested); this class only talks to Android.
///
/// Notifications are scheduled with [AndroidScheduleMode.inexactAllowWhileIdle]: no special
/// "exact alarm" permission (which Google Play restricts to alarm/calendar apps) and still fires
/// while the phone is idle — it can arrive a few minutes late, which is fine for a payment
/// reminder.
class ReminderNotificationService {
  ReminderNotificationService([FlutterLocalNotificationsPlugin? plugin]) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const channelId = 'payment_reminders';

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Safe to call more than once. [onTap] receives the account id when a notification is opened
  /// (also when it is what launched the app).
  Future<void> initialize({required void Function(String accountId) onTap}) async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap(payload);
      },
    );
    _ready = true;
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) && payload != null && payload.isNotEmpty) onTap(payload);
    } catch (e) {
      debugPrint('[reminders] launch details unavailable: $e');
    }
  }

  /// Asks for the Android 13+ notification permission (older versions have none to ask for).
  /// Returns whether notifications can be shown now.
  Future<bool> requestPermission() async {
    try {
      final android = _android;
      if (android == null) return true;
      final granted = await android.requestNotificationsPermission();
      return granted ?? await android.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> areEnabled() async {
    try {
      return await _android?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  int _idFor(AccountReminder r, int slot) => r.notificationBase * reminderSlots + slot;

  Future<void> cancel(AccountReminder reminder) async {
    for (var k = 0; k < reminderSlots; k++) {
      await _plugin.cancel(id: _idFor(reminder, k));
    }
  }

  /// Replaces every pending notification of [reminder] with the upcoming ones.
  Future<void> schedule({
    required AccountReminder reminder,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
    DateTime? now,
  }) async {
    await cancel(reminder);
    final times = upcomingOccurrences(reminder, now ?? DateTime.now(), count: slotsToSchedule(reminder.repeat));
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    for (var i = 0; i < times.length && i < reminderSlots; i++) {
      await _plugin.zonedSchedule(
        id: _idFor(reminder, i),
        title: title,
        body: body,
        // An absolute instant: the UTC location is only a carrier; the exact moment is the
        // device-local time the person picked.
        scheduledDate: tz.TZDateTime.from(times[i], tz.UTC),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminder.accountId,
      );
    }
  }
}
