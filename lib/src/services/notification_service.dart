import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/booking.dart';
import '../utils/time_utils.dart';

/// Game reminders. When a booking is confirmed we schedule a notification
/// on the phone itself for 2 hours before the start time — no server
/// needed, works offline. Firebase Messaging is also initialized so the
/// club can send announcement pushes later.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz.identifier));
    } catch (_) {
      // Keep the default (UTC) if the platform lookup fails.
    }

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      settings:
          const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {
      // Messaging is optional; ignore if unavailable (e.g. no APNs yet).
    }
    _ready = true;
  }

  /// Schedules the "game in 2 hours" reminder. Skipped when the game is
  /// less than 2 hours away.
  Future<void> scheduleGameReminder({
    required String bookingId,
    required Booking booking,
    required String title,
    required String body,
  }) async {
    await init();
    final remindAt =
        booking.startDateTime.subtract(const Duration(hours: 2));
    if (remindAt.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id: bookingId.hashCode,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(remindAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'game_reminders',
          'Game reminders',
          channelDescription: 'Reminders before your booked games',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelGameReminder(String bookingId) =>
      _plugin.cancel(id: bookingId.hashCode);
}

/// Convenience for reminder body text.
String reminderBodyFor(Booking b) =>
    '${b.branchName} — ${b.courtName}, ${formatMinutes(b.startMinutes)}';
