import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/localization/generated/app_localizations.dart';
import '../../data/models/healthcare/appointment.dart';

/// Presentation helpers for the healthcare feature.
///
/// Appointment times are instants stored with the clinic's IANA zone, so
/// they are always rendered **in the clinic's time**, never the phone's —
/// a patient who travels still sees the time the clinic wrote down.
class HealthcareFormat {
  HealthcareFormat._();

  static bool _tzReady = false;

  static tz.Location? _location(String? zone) {
    if (zone == null || zone.isEmpty) return null;
    if (!_tzReady) {
      // NotificationService initializes the same database at boot; this only
      // covers direct calls (tests, or a screen opened before boot finished).
      try {
        tzdata.initializeTimeZones();
      } catch (_) {}
      _tzReady = true;
    }
    try {
      return tz.getLocation(zone);
    } catch (_) {
      return null;
    }
  }

  /// The wall-clock time at [instant] in [zone] (falls back to device local
  /// time when the zone is unknown).
  static DateTime wallClock(DateTime instant, String? zone) {
    final location = _location(zone);
    if (location == null) return instant.toLocal();
    final zoned = tz.TZDateTime.from(instant, location);
    return DateTime(
      zoned.year,
      zoned.month,
      zoned.day,
      zoned.hour,
      zoned.minute,
    );
  }

  /// e.g. `10:30 AM`.
  static String time(DateTime instant, String? zone, String locale) =>
      DateFormat('h:mm a', locale).format(wallClock(instant, zone));

  /// e.g. `Tue, 23 Sep`.
  static String dayShort(DateTime instant, String? zone, String locale) =>
      DateFormat('EEE, d MMM', locale).format(wallClock(instant, zone));

  /// e.g. `Tue, 23 Sep 2026`.
  static String dayMedium(DateTime instant, String? zone, String locale) =>
      DateFormat('EEE, d MMM yyyy', locale).format(wallClock(instant, zone));

  /// e.g. `Tuesday, 23 September`.
  static String dayLong(DateTime instant, String? zone, String locale) =>
      DateFormat('EEEE, d MMMM', locale).format(wallClock(instant, zone));

  /// Calendar day (midnight, no time) of [instant] in [zone].
  static DateTime calendarDay(DateTime instant, String? zone) {
    final wall = wallClock(instant, zone);
    return DateTime(wall.year, wall.month, wall.day);
  }

  /// `"Today"`, `"Tomorrow"`, or the short weekday label.
  static String relativeDayLabel(
    DateTime instant,
    String? zone,
    String locale,
    AppLocalizations l10n, {
    DateTime? now,
  }) {
    final day = calendarDay(instant, zone);
    final today = now == null
        ? DateTime.now()
        : (zone == null ? now : wallClock(now, zone));
    final todayDay = DateTime(today.year, today.month, today.day);
    final difference = day.difference(todayDay).inDays;
    if (difference == 0) return l10n.hcRelToday;
    if (difference == 1) return l10n.hcRelTomorrow;
    return dayShort(instant, zone, locale);
  }

  /// `"In 20 min"` / `"Starting soon"` — null when the instant is in the past.
  static String? relativeToNow(
    DateTime instant,
    AppLocalizations l10n, {
    DateTime? now,
  }) {
    final reference = (now ?? DateTime.now()).toUtc();
    final difference = instant.difference(reference);
    if (difference.isNegative) return null;
    final minutes = difference.inMinutes;
    if (minutes < 5) return l10n.hcRelStartingSoon;
    if (minutes < 90) return l10n.hcRelInMinutes(minutes);
    final hours = difference.inHours;
    if (hours < 24) return l10n.hcRelInHours(hours);
    return null;
  }

  /// Consultation fee, from currency minor units. Returns null when the
  /// clinic has not published a fee — never a placeholder number.
  static String? fee(int? consultationFeeMinor) {
    if (consultationFeeMinor == null) return null;
    final major = consultationFeeMinor / 100;
    final isWhole = consultationFeeMinor % 100 == 0;
    final text = NumberFormat.decimalPattern().format(
      isWhole ? major.round() : major,
    );
    return '₹$text';
  }

  /// Short, human-friendly handle for an appointment id (long UUIDs are
  /// unreadable over the phone).
  static String reference(String id) {
    final compact = id.replaceAll('-', '').toUpperCase();
    if (compact.isEmpty) return id;
    final tail = compact.length > 8 ? compact.substring(0, 8) : compact;
    return tail;
  }

  static String statusLabel(AppointmentStatus status, AppLocalizations l10n) {
    switch (status) {
      case AppointmentStatus.requested:
        return l10n.hcStatusRequested;
      case AppointmentStatus.confirmed:
        return l10n.hcStatusConfirmed;
      case AppointmentStatus.checkedIn:
        return l10n.hcStatusCheckedIn;
      case AppointmentStatus.waiting:
        return l10n.hcStatusWaiting;
      case AppointmentStatus.inConsultation:
        return l10n.hcStatusInConsultation;
      case AppointmentStatus.completed:
        return l10n.hcStatusCompleted;
      case AppointmentStatus.cancelled:
        return l10n.hcStatusCancelled;
      case AppointmentStatus.noShow:
        return l10n.hcStatusNoShow;
      case AppointmentStatus.rescheduled:
        return l10n.hcStatusRescheduled;
      case AppointmentStatus.unknown:
        return l10n.hcStatusUnknown;
    }
  }

  static String queueStateLabel(String state, AppLocalizations l10n) {
    switch (state) {
      case 'WAITING':
        return l10n.hcStatusWaiting;
      case 'CALLED':
        return l10n.hcQueueCalled;
      case 'IN_CONSULTATION':
        return l10n.hcStatusInConsultation;
      case 'COMPLETED':
        return l10n.hcStatusCompleted;
      case 'SKIPPED':
        return l10n.hcStatusCancelled;
      default:
        return l10n.hcStatusUnknown;
    }
  }

  /// Organization type → label. The type value itself always comes from the
  /// API; only the label is local.
  static String organizationTypeLabel(String? orgType, AppLocalizations l10n) {
    switch (orgType) {
      case 'HOSPITAL':
        return l10n.hcTypeHospital;
      case 'CLINIC':
        return l10n.hcTypeClinic;
      case 'POLYCLINIC':
        return l10n.hcTypePolyclinic;
      case 'DIAGNOSTIC_CENTER':
        return l10n.hcTypeDiagnostic;
      case 'OTHER':
        return l10n.hcTypeOther;
      default:
        return l10n.hcTypeOther;
    }
  }
}
