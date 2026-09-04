import '../../data/models/food_instruction.dart';
import '../localization/l10n_helper.dart';
import '../utilities/date_utils.dart';

/// Strings used when scheduling notifications (no BuildContext available at
/// schedule time). Built from the current locale's [AppLocalizations].
class ReminderText {
  const ReminderText({
    required this.localeCode,
    required this.titleBuilder,
    required this.takenLabel,
    required this.snoozeLabel,
    required this.skipLabel,
    required this.bodyBuilder,
    required this.foodLabelBuilder,
    required this.missedAlertTitle,
    required this.missedAlertBodyBuilder,
  });

  final String localeCode;
  final String Function(String name) titleBuilder;
  final String takenLabel;
  final String snoozeLabel;
  final String skipLabel;
  final String Function(String name, String info) bodyBuilder;
  final String Function(FoodInstruction food) foodLabelBuilder;
  final String missedAlertTitle;
  final String Function(String name, String time) missedAlertBodyBuilder;

  factory ReminderText.from(String localeCode, {required int snoozeMinutes}) {
    final l10n = l10nFor(localeCode);
    return ReminderText(
      localeCode: localeCode,
      titleBuilder: (name) => l10n.notifTitleFor(name),
      takenLabel: l10n.notifActionTaken,
      snoozeLabel: l10n.notifActionSnooze(snoozeMinutes),
      skipLabel: l10n.notifActionSkip,
      bodyBuilder: (name, info) => l10n.notifBody(name, info),
      foodLabelBuilder: (f) => switch (f) {
        FoodInstruction.before => l10n.foodBefore,
        FoodInstruction.after => l10n.foodAfter,
        FoodInstruction.withFood => l10n.foodWith,
        FoodInstruction.none => '',
      },
      missedAlertTitle: l10n.missedAlertTitle,
      missedAlertBodyBuilder: (name, time) => l10n.missedAlertBody(name, time),
    );
  }

  String title(String name) => titleBuilder(name);
  String body(String name, String info) => bodyBuilder(name, info);
  String foodLabel(FoodInstruction f) => foodLabelBuilder(f);

  /// The "what & when" line for a dose notification, e.g.
  /// "1 tablet · 20 mg · after food · 2:30 PM" — so the user knows exactly
  /// which medicine to take without opening the app.
  String info(String doseLabel, FoodInstruction food, DateTime doseTime) {
    final parts = <String>[
      if (doseLabel.trim().isNotEmpty) doseLabel.trim(),
      if (food != FoodInstruction.none) foodLabel(food),
      AppDateUtils.timeLabel(doseTime, localeCode),
    ];
    return parts.join(' · ');
  }

  String missedAlertBody(String name, String time) =>
      missedAlertBodyBuilder(name, time);
}
