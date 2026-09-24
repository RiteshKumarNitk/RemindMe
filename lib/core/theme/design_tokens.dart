import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// DoseWise design tokens.
///
/// One place for every spacing, radius, size and semantic colour in the app.
/// Widgets must not hardcode these values — screens import the tokens (or the
/// shared widgets built on top of them) instead of inventing their own.
///
/// The scale is deliberately large: the primary user is an elderly person who
/// may have reduced vision, reduced dexterity and little smartphone experience.
/// ---------------------------------------------------------------------------

/// 4-point spacing scale. Use these instead of arbitrary padding values.
abstract final class AppSpacing {
  /// 4 — hair-thin separation (icon ↔ label inside a chip).
  static const double xxs = 4;

  /// 8 — tight separation (label ↔ value).
  static const double xs = 8;

  /// 12 — between related rows.
  static const double sm = 12;

  /// 16 — inside a card / between form fields.
  static const double md = 16;

  /// 20 — screen side padding.
  static const double lg = 20;

  /// 24 — between sections.
  static const double xl = 24;

  /// 32 — between major blocks.
  static const double xxl = 32;

  /// 40 — above a primary action at the end of a screen.
  static const double xxxl = 40;

  /// Standard horizontal screen padding.
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: lg);

  /// Standard page content padding (top gap + screen sides).
  static const EdgeInsets page = EdgeInsets.fromLTRB(lg, sm, lg, md);
}

/// Corner radii. A small, consistent set — nothing is "extremely rounded".
abstract final class AppRadius {
  /// 10 — chips, badges, tiny surfaces.
  static const double xs = 10;

  /// 14 — inputs, secondary buttons.
  static const double sm = 14;

  /// 18 — cards, primary buttons.
  static const double md = 18;

  /// 24 — sheets, dialogs, hero surfaces.
  static const double lg = 24;

  /// Fully rounded (pills).
  static const double pill = 999;

  static BorderRadius get chipRadius => BorderRadius.circular(xs);
  static BorderRadius get controlRadius => BorderRadius.circular(sm);
  static BorderRadius get cardRadius => BorderRadius.circular(md);
  static BorderRadius get sheetRadius => BorderRadius.circular(lg);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
}

/// Fixed control sizes. All interactive targets are ≥ 52 logical pixels.
abstract final class AppSizes {
  /// Primary / secondary button height. Large enough for an unsteady hand.
  static const double button = 60;

  /// Hero action ("TAKE MEDICINE") height.
  static const double heroButton = 68;

  /// Text field height.
  static const double field = 60;

  /// Minimum tap target for icon-only controls (Material asks for 48).
  static const double tapTarget = 52;

  /// Bottom navigation bar height.
  static const double navBar = 76;

  /// Icon sizes.
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 26;
  static const double iconXl = 32;

  /// Leading avatar / status circle on list rows.
  static const double avatar = 48;

  /// Width of the vertical timeline rail on the daily schedule.
  static const double timelineRail = 26;

  /// Maximum readable content width on tablets / landscape.
  static const double maxContentWidth = 560;
}

/// Motion. Short, calm and functional — never decorative.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
}

/// Semantic colours that are not part of Material's [ColorScheme] — dose
/// outcomes, gentle warnings and the surfaces used for tinted blocks.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.neutralContainer,
    required this.onNeutralContainer,
    required this.cardBorder,
    required this.heroSurface,
    required this.heroBorder,
  });

  /// Taken / completed.
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;

  /// Due soon / needs attention (never used alone — always with an icon).
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;

  /// Informational, calm highlight (next dose, tips).
  final Color info;
  final Color infoContainer;
  final Color onInfoContainer;

  /// Skipped / inactive — deliberately quiet and grey.
  final Color neutralContainer;
  final Color onNeutralContainer;

  /// 1px hairline around cards and list rows.
  final Color cardBorder;

  /// Surface + border of the "next medicine" hero block.
  final Color heroSurface;
  final Color heroBorder;

  @override
  AppPalette copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? neutralContainer,
    Color? onNeutralContainer,
    Color? cardBorder,
    Color? heroSurface,
    Color? heroBorder,
  }) {
    return AppPalette(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      neutralContainer: neutralContainer ?? this.neutralContainer,
      onNeutralContainer: onNeutralContainer ?? this.onNeutralContainer,
      cardBorder: cardBorder ?? this.cardBorder,
      heroSurface: heroSurface ?? this.heroSurface,
      heroBorder: heroBorder ?? this.heroBorder,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      success: l(success, other.success),
      successContainer: l(successContainer, other.successContainer),
      onSuccessContainer: l(onSuccessContainer, other.onSuccessContainer),
      warning: l(warning, other.warning),
      warningContainer: l(warningContainer, other.warningContainer),
      onWarningContainer: l(onWarningContainer, other.onWarningContainer),
      info: l(info, other.info),
      infoContainer: l(infoContainer, other.infoContainer),
      onInfoContainer: l(onInfoContainer, other.onInfoContainer),
      neutralContainer: l(neutralContainer, other.neutralContainer),
      onNeutralContainer: l(onNeutralContainer, other.onNeutralContainer),
      cardBorder: l(cardBorder, other.cardBorder),
      heroSurface: l(heroSurface, other.heroSurface),
      heroBorder: l(heroBorder, other.heroBorder),
    );
  }

  /// Light palette: white surfaces, deep calm teal, muted status colours.
  static const AppPalette light = AppPalette(
    success: Color(0xFF1B7A45),
    successContainer: Color(0xFFE1F4E7),
    onSuccessContainer: Color(0xFF0C4125),
    warning: Color(0xFF9A6200),
    warningContainer: Color(0xFFFDEFD6),
    onWarningContainer: Color(0xFF5C3A00),
    info: Color(0xFF0F6B63),
    infoContainer: Color(0xFFE0F2EF),
    onInfoContainer: Color(0xFF06403A),
    neutralContainer: Color(0xFFEDF1F1),
    onNeutralContainer: Color(0xFF4A5A59),
    cardBorder: Color(0xFFDCE5E4),
    heroSurface: Color(0xFFF2F9F7),
    heroBorder: Color(0xFFCDE5E0),
  );

  /// Dark palette: same meanings, lifted for contrast on dark surfaces.
  static const AppPalette dark = AppPalette(
    success: Color(0xFF7BD99C),
    successContainer: Color(0xFF14361F),
    onSuccessContainer: Color(0xFFB9EFC9),
    warning: Color(0xFFFFCE7A),
    warningContainer: Color(0xFF3B2A08),
    onWarningContainer: Color(0xFFFFE2AE),
    info: Color(0xFF7FD3CA),
    infoContainer: Color(0xFF0C3A35),
    onInfoContainer: Color(0xFFBEEBE5),
    neutralContainer: Color(0xFF212B2A),
    onNeutralContainer: Color(0xFFB6C4C2),
    cardBorder: Color(0xFF2C3A38),
    heroSurface: Color(0xFF13201E),
    heroBorder: Color(0xFF274440),
  );
}

/// Ergonomic access to the palette: `context.palette.success`.
extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
