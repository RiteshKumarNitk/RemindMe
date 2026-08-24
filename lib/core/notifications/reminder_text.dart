import '../localization/l10n_helper.dart';

/// Strings used when scheduling notifications (no BuildContext available at
/// schedule time). Built from the current locale's [AppLocalizations].
class ReminderText {
  const ReminderText({
    required this.title,
    required this.takenLabel,
    required this.snoozeLabel,
    required this.skipLabel,
    required this.bodyBuilder,
    required this.missedAlertTitle,
    required this.missedAlertBodyBuilder,
  });

  final String title;
  final String takenLabel;
  final String snoozeLabel;
  final String skipLabel;
  final String Function(String name, String dose) bodyBuilder;
  final String missedAlertTitle;
  final String Function(String name, String time) missedAlertBodyBuilder;

  factory ReminderText.from(String localeCode, {required int snoozeMinutes}) {
    final l10n = l10nFor(localeCode);
    return ReminderText(
      title: l10n.notifTitle,
      takenLabel: l10n.notifActionTaken,
      snoozeLabel: l10n.notifActionSnooze(snoozeMinutes),
      skipLabel: l10n.notifActionSkip,
      bodyBuilder: (name, dose) => l10n.notifBody(name, dose),
      missedAlertTitle: l10n.missedAlertTitle,
      missedAlertBodyBuilder: (name, time) => l10n.missedAlertBody(name, time),
    );
  }

  String missedAlertBody(String name, String time) =>
      missedAlertBodyBuilder(name, time);

  String body(String name, String dose) => bodyBuilder(name, dose);
}
