import 'package:intl/intl.dart';

/// Small date/time helpers shared across the app.
class AppDateUtils {
  AppDateUtils._();

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Monday-based start of the week (ISO).
  static DateTime startOfWeek(DateTime d) {
    final day = startOfDay(d);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  /// e.g. "8:00 AM" (locale aware).
  static String timeLabel(DateTime d, String locale) =>
      DateFormat('h:mm a', locale).format(d);

  /// e.g. "Mon, 17 Aug".
  static String dayLabel(DateTime d, String locale) =>
      DateFormat('EEE, d MMM', locale).format(d);

  /// e.g. "Monday".
  static String weekdayLabel(int weekday, String locale) => DateFormat(
    'EEEE',
    locale,
  ).format(DateTime(2024, 1, 1 + weekday - DateTime.monday));

  /// Short weekday e.g. "Mon".
  static String weekdayShort(int weekday, String locale) => DateFormat(
    'EEE',
    locale,
  ).format(DateTime(2024, 1, 1 + weekday - DateTime.monday));

  static String dateLabel(DateTime d, String locale) =>
      DateFormat('d MMM yyyy', locale).format(d);
}
