import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/localization/l10n_helper.dart';
import '../core/notifications/notification_service.dart';
import '../data/models/dose_status.dart';
import '../data/repositories/dose_repository.dart';
import '../services/settings_controller.dart';

/// Monitors for missed doses and sends escalating follow-up notifications.
///
/// Escalation timeline:
/// - 0 min after grace: first "Missed dose" notification (vibrate only)
/// - 15 min later: second notification with sound (louder)
/// - 30 min later: third notification + family alert if enabled
/// - 60 min later: final "URGENT" alert
class MissedDoseEscalation {
  MissedDoseEscalation({
    required this.doseRepository,
    required this.notifications,
    required this.settings,
  });

  final DoseRepository doseRepository;
  final NotificationService notifications;
  final SettingsController settings;

  Timer? _timer;
  final Set<int> _escalatedDoses = {};
  final Map<int, int> _escalationLevel = {};

  /// Starts periodic checking (every 5 minutes) for missed doses.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _check());
    // Also check immediately
    _check();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    if (!settings.settings.missedAlertsEnabled) return;

    final now = DateTime.now();
    final grace = settings.graceDuration;
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final entries = await doseRepository.getEntriesBetween(start, end);
    final l10n = l10nFor(settings.settings.locale);

    for (final entry in entries) {
      final status = entry.effectiveStatus(grace, now);
      if (status != DoseStatus.missed) continue;

      final doseId = entry.dose.id!;
      final elapsed = now.difference(entry.dose.scheduledAt);
      final elapsedMin = elapsed.inMinutes;

      // Determine escalation level based on time since scheduled
      int level;
      if (elapsedMin < 15) {
        level = 0; // Just missed
      } else if (elapsedMin < 30) {
        level = 1; // 15+ min late
      } else if (elapsedMin < 60) {
        level = 2; // 30+ min late
      } else {
        level = 3; // 1+ hour late
      }

      // Don't re-escalate if we've already sent this level
      final currentLevel = _escalationLevel[doseId] ?? -1;
      if (level <= currentLevel) continue;

      _escalationLevel[doseId] = level;
      _escalatedDoses.add(doseId);

      await _sendEscalation(entry, level, elapsedMin, l10n);
    }
  }

  Future<void> _sendEscalation(
    dynamic entry,
    int level,
    int elapsedMin,
    dynamic l10n,
  ) async {
    final name = entry.medicine.name;
    final dose = entry.medicine.doseLabel;
    final time = entry.dose.scheduledAt;
    final doseId = entry.dose.id;

    String title;
    String body;

    switch (level) {
      case 0:
        title = l10n.missedAlertTitle;
        body = l10n.missedAlertBody(name, _formatTime(time));
      case 1:
        title = '⚠️ $name — still not taken';
        body = 'This dose was due $elapsedMin minutes ago. Please take it now.';
      case 2:
        title = '🔴 URGENT: $name not taken';
        body =
            'This dose was due over 30 minutes ago ($dose). Please take it immediately or contact your doctor.';
      case 3:
        title = '🚨 CRITICAL: $name missed for 1+ hour';
        body =
            '$name ($dose) was due at ${_formatTime(time)} and has not been taken for over an hour. Please check on the patient.';
      default:
        return;
    }

    debugPrint(
      'MissedDoseEscalation: level=$level dose=$doseId elapsed=${elapsedMin}min',
    );

    await notifications.showMissedAlert(title: title, body: body);
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:$m $period';
  }

  /// Resets escalation tracking (called when a dose is taken/skipped).
  void resetDose(int doseId) {
    _escalatedDoses.remove(doseId);
    _escalationLevel.remove(doseId);
  }

  void dispose() {
    _timer?.cancel();
  }
}
