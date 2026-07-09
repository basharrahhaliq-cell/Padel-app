import 'package:intl/intl.dart';

/// Club-wide scheduling constants.
/// All times of day are stored as "minutes since midnight" integers,
/// e.g. 8:00 AM = 480, 11:00 PM = 1380.
class ClubHours {
  ClubHours._();

  static const int openMinutes = 8 * 60; // 8:00 AM
  static const int closeMinutes = 23 * 60; // 11:00 PM
  static const int slotStepMinutes = 30;
  static const List<int> gameDurations = [60, 90, 120];
}

/// Formats 570 -> "9:30 AM".
String formatMinutes(int minutesSinceMidnight) {
  final h = minutesSinceMidnight ~/ 60;
  final m = minutesSinceMidnight % 60;
  final dt = DateTime(2000, 1, 1, h, m);
  return DateFormat.jm().format(dt);
}

/// Canonical date key used across Firestore: "2026-07-09".
String dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

DateTime parseDateKey(String key) => DateTime.parse(key);

/// Combines a date and minutes-since-midnight into a local DateTime.
DateTime dateTimeOf(DateTime date, int minutes) =>
    DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60);

/// ISO weekday for a date key: Monday = 1 ... Sunday = 7.
int weekdayOf(String key) => parseDateKey(key).weekday;
