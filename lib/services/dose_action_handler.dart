import '../core/constants/app_constants.dart';
import '../core/localization/l10n_helper.dart';
import '../core/notifications/notification_service.dart';
import '../core/notifications/reminder_text.dart';
import '../data/repositories/dose_repository.dart';
import '../data/repositories/medicine_repository.dart';
import 'settings_controller.dart';
import 'voice_service.dart';

/// Handles a notification tap or action-button press (TAKEN / SNOOZE / SKIP),
/// both from the background callback and from a cold start via launch
/// details.
class DoseActionHandler {
  DoseActionHandler({
    required this.doseRepository,
    required this.medicineRepository,
    required this.scheduler,
    required this.settings,
    required this.voice,
  });

  final DoseRepository doseRepository;
  final MedicineRepository medicineRepository;
  final ReminderScheduler scheduler;
  final SettingsController settings;
  final VoiceService voice;

  Future<void> handle({
    String? actionId,
    String? payload,
    DateTime? now,
    bool speak = true,
  }) async {
    final doseId = _parseDoseId(payload);
    if (doseId == null) return;
    final dose = await doseRepository.getDose(doseId);
    if (dose == null) return;
    final medicine = await medicineRepository.getById(dose.medicineId);
    if (medicine == null) return;

    final time = now ?? DateTime.now();
    switch (actionId) {
      case AppConstants.actionTaken:
        await doseRepository.markTaken(doseId, time);
        await scheduler.cancel(doseId);
        if (speak && settings.voiceEnabled) {
          final l10n = l10nFor(settings.settings.locale);
          await voice.speak(l10n.voiceTaken, settings.settings.locale);
        }
      case AppConstants.actionSkip:
        await doseRepository.markSkipped(doseId, time);
        await scheduler.cancel(doseId);
      case AppConstants.actionSnooze:
        final until = time.add(settings.snoozeDuration);
        await doseRepository.setSnoozedUntil(doseId, until);
        await scheduler.cancel(doseId);
        final text = ReminderText.from(
          settings.settings.locale,
          snoozeMinutes: settings.snoozeMinutes,
        );
        await scheduler.scheduleDoseReminder(
          doseId: doseId,
          title: text.title,
          body: text.body(medicine.name, medicine.doseLabel),
          when: until,
          exact: true, // falls back to inexact inside the service if needed
          takenLabel: text.takenLabel,
          snoozeLabel: text.snoozeLabel,
          skipLabel: text.skipLabel,
        );
    }
  }

  int? _parseDoseId(String? payload) {
    if (payload == null || !payload.startsWith(AppConstants.payloadPrefix)) {
      return null;
    }
    return int.tryParse(payload.substring(AppConstants.payloadPrefix.length));
  }
}
