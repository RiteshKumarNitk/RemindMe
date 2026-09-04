import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../data/models/dose_entry.dart';
import '../data/models/dose_status.dart';

/// Pushes next-dose information to the Android home screen widget.
///
/// The widget is purely native (RemoteViews) — Flutter cannot draw it.
/// This service writes key-value pairs to SharedPreferences via
/// [HomeWidget.saveWidgetData] and then asks Android to re-render.
class HomeWidgetService {
  /// Updates the home screen widget with the next pending dose.
  ///
  /// Call this after every `refresh()` in AppState so the widget stays current.
  static Future<void> update({
    required List<DoseEntry> todayDoses,
    required DateTime now,
    String locale = 'en',
  }) async {
    try {
      // Find the next pending dose (closest to now, in the future).
      DoseEntry? nextDose;
      for (final entry in todayDoses) {
        if (entry.dose.status != DoseStatus.pending) continue;
        final scheduled = entry.dose.snoozedUntil ?? entry.dose.scheduledAt;
        if (scheduled.isAfter(now)) {
          if (nextDose == null || scheduled.isBefore(nextDose.dose.scheduledAt)) {
            nextDose = entry;
          }
        }
      }

      // If no future dose, find the most recent pending (overdue).
      if (nextDose == null) {
        for (final entry in todayDoses) {
          if (entry.dose.status != DoseStatus.pending) continue;
          nextDose = entry;
          break;
        }
      }

      if (nextDose == null) {
        // No pending doses — all done today.
        await HomeWidget.saveWidgetData<String>(
          'widget_medicine_name',
          '',
        );
        await HomeWidget.saveWidgetData<bool>('widget_all_done', true);
        await HomeWidget.saveWidgetData<String>(
          'widget_dose_info',
          '',
        );
        await HomeWidget.saveWidgetData<String>(
          'widget_dose_time',
          '',
        );
        await HomeWidget.saveWidgetData<String>(
          'widget_status_text',
          '',
        );
      } else {
        final med = nextDose.medicine;
        final dose = nextDose.dose;
        final scheduled = dose.snoozedUntil ?? dose.scheduledAt;
        final timeFormat = DateFormat('h:mm a', locale);
        final timeStr = timeFormat.format(scheduled);

        // Compute status text.
        final diff = scheduled.difference(now);
        String status;
        if (diff.isNegative) {
          final overdue = now.difference(scheduled);
          if (overdue.inMinutes <= 30) {
            // Within grace period — show "Due now!" so the user knows to
            // take the medicine immediately.
            status = '🔴 Due now!';
          } else if (overdue.inMinutes < 60) {
            status = '⏰ ${overdue.inMinutes} min late';
          } else {
            status = '⏰ ${overdue.inHours}h late';
          }
        } else if (diff.inMinutes < 5) {
          status = '🔴 Due now!';
        } else if (diff.inMinutes < 60) {
          status = '🟡 in ${diff.inMinutes} min';
        } else {
          status = '🟢 in ${diff.inHours}h ${diff.inMinutes % 60}m';
        }

        // Dose info text.
        final doseInfo = med.doseLabel.isNotEmpty ? med.doseLabel : '';

        await HomeWidget.saveWidgetData<String>(
          'widget_medicine_name',
          med.name,
        );
        await HomeWidget.saveWidgetData<bool>('widget_all_done', false);
        await HomeWidget.saveWidgetData<String>(
          'widget_dose_info',
          doseInfo,
        );
        await HomeWidget.saveWidgetData<String>(
          'widget_dose_time',
          timeStr,
        );
        await HomeWidget.saveWidgetData<String>(
          'widget_status_text',
          status,
        );
      }

      // Tell Android to re-render the widget.
      await HomeWidget.updateWidget(
        name: 'DoseWidgetProvider',
        androidName: 'DoseWidgetProvider',
      );
    } catch (e) {
      debugPrint('HomeWidgetService.update error: $e');
    }
  }
}
