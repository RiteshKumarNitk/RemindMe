import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// ---------------------------------------------------------------------------
/// DoseWise theme.
///
/// Clean, calm, healthcare. One palette, one type scale, one spacing system —
/// built for an elderly user first: large type, high contrast, generous touch
/// targets and one obvious primary action per screen.
///
/// Nothing here is decorative: no gradients behind content, no heavy shadows,
/// no rounded-corner-on-everything. Hierarchy comes from type and whitespace.
/// ---------------------------------------------------------------------------
class AppTheme {
  AppTheme._();

  /// Calm medical teal — trustworthy, low-arousal, distinct from the red/amber
  /// used for "due now" and "missed".
  static const Color seed = Color(0xFF0F6B63);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF0F6B63),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD3EDE8),
      onPrimaryContainer: const Color(0xFF05332E),
      secondary: const Color(0xFF45615D),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFDCE9E6),
      onSecondaryContainer: const Color(0xFF1B312E),
      tertiary: const Color(0xFF7A5A1E),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFFBE8CF),
      onTertiaryContainer: const Color(0xFF3E2A00),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF131C1B),
      onSurfaceVariant: const Color(0xFF4A5A59),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF7FAF9),
      surfaceContainer: const Color(0xFFF1F6F5),
      surfaceContainerHigh: const Color(0xFFE9F0EF),
      surfaceContainerHighest: const Color(0xFFE1E9E8),
      outline: const Color(0xFF73827F),
      outlineVariant: const Color(0xFFD6DFDD),
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: const Color(0xFFFBE4E1),
      onErrorContainer: const Color(0xFF4E0F0A),
      inverseSurface: const Color(0xFF2C3634),
      onInverseSurface: const Color(0xFFEDF2F1),
    );
    return _build(scheme, AppPalette.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF7FD3CA),
      onPrimary: const Color(0xFF00332E),
      primaryContainer: const Color(0xFF0E4A45),
      onPrimaryContainer: const Color(0xFFCDECE7),
      secondary: const Color(0xFFB0CCC7),
      onSecondary: const Color(0xFF173230),
      secondaryContainer: const Color(0xFF2E4744),
      onSecondaryContainer: const Color(0xFFCDEAE5),
      tertiary: const Color(0xFFE8C48A),
      onTertiary: const Color(0xFF3F2E00),
      tertiaryContainer: const Color(0xFF5A4318),
      onTertiaryContainer: const Color(0xFFFFE3B6),
      surface: const Color(0xFF0F1413),
      onSurface: const Color(0xFFE6ECEA),
      onSurfaceVariant: const Color(0xFFB6C4C2),
      surfaceContainerLowest: const Color(0xFF0A0F0E),
      surfaceContainerLow: const Color(0xFF141A19),
      surfaceContainer: const Color(0xFF18201F),
      surfaceContainerHigh: const Color(0xFF1F2928),
      surfaceContainerHighest: const Color(0xFF263231),
      outline: const Color(0xFF8A9997),
      outlineVariant: const Color(0xFF313E3C),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      inverseSurface: const Color(0xFFE6ECEA),
      onInverseSurface: const Color(0xFF1B2221),
    );
    return _build(scheme, AppPalette.dark);
  }

  static ThemeData _build(ColorScheme scheme, AppPalette palette) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = _textTheme(base.textTheme, scheme);

    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpacing.xl);

    ButtonStyle solidButton({
      double height = AppSizes.button,
      Color? background,
      Color? foreground,
    }) {
      return ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size.fromHeight(height)),
        padding: const WidgetStatePropertyAll(buttonPadding),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: background == null
            ? null
            : WidgetStatePropertyAll(background),
        foregroundColor: foreground == null
            ? null
            : WidgetStatePropertyAll(foreground),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.controlRadius),
        ),
      );
    }

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      extensions: [palette],

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        titleTextStyle: text.headlineSmall,
        iconTheme: IconThemeData(color: scheme.onSurface, size: AppSizes.iconLg),
      ),

      filledButtonTheme: FilledButtonThemeData(style: solidButton()),
      elevatedButtonTheme: ElevatedButtonThemeData(style: solidButton()),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: solidButton().copyWith(
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant, width: 1.5),
          ),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(64, AppSizes.tapTarget),
          ),
          padding: const WidgetStatePropertyAll(buttonPadding),
          foregroundColor: WidgetStatePropertyAll(scheme.primary),
          textStyle: WidgetStatePropertyAll(
            text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.controlRadius),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSizes.tapTarget, AppSizes.tapTarget),
          ),
          iconSize: const WidgetStatePropertyAll(AppSizes.iconLg),
          visualDensity: VisualDensity.standard,
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
        ),
      ),

      // Plain Material bar: always labelled (never icon-only), large targets,
      // selected state carried by a filled pill *and* a colour + weight change.
      navigationBarTheme: NavigationBarThemeData(
        height: AppSizes.navBar,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? text.labelLarge?.copyWith(color: scheme.primary, fontSize: 14)
              : text.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: AppSizes.iconLg,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: palette.cardBorder),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        labelStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: text.bodyMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: scheme.outline),
        errorStyle: text.bodyMedium?.copyWith(color: scheme.error),
        border: OutlineInputBorder(
          borderRadius: AppRadius.controlRadius,
          borderSide: BorderSide(color: palette.cardBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.controlRadius,
          borderSide: BorderSide(color: palette.cardBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.controlRadius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.controlRadius,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.controlRadius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),

      chipTheme: base.chipTheme.copyWith(
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge,
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: palette.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        showCheckmark: true,
        checkmarkColor: scheme.primary,
        disabledColor: scheme.surfaceContainer,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(0, AppSizes.tapTarget),
          ),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          side: WidgetStatePropertyAll(
            BorderSide(color: palette.cardBorder, width: 1.5),
          ),
        ),
      ),

      switchTheme: SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        minTileHeight: 64,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.sheetRadius,
          side: BorderSide(color: palette.cardBorder),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        constraints: const BoxConstraints(maxWidth: 640),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        contentTextStyle: text.bodyLarge?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.controlRadius,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: palette.cardBorder,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
        borderRadius: AppRadius.pillRadius,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.controlRadius,
          side: BorderSide(color: palette.cardBorder),
        ),
        textStyle: text.bodyLarge,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: AppRadius.chipRadius,
        ),
        textStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      ),
    );
  }

  /// Type scale. Sizes are deliberately a step above Material's defaults and
  /// nothing important is smaller than 16pt.
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    final muted = scheme.onSurfaceVariant;
    return base.copyWith(
      // Reserved for the single number/headline on a screen.
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 38,
        fontWeight: FontWeight.w800,
        height: 1.12,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
      // Screen titles.
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 25,
        fontWeight: FontWeight.w700,
        height: 1.22,
      ),
      // Hero content (the medicine name that is due now).
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      // Section headers.
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      // List-row titles, form field values.
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      // Primary reading size.
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 17, height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 15.5,
        height: 1.45,
        color: muted,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 14,
        height: 1.4,
        color: muted,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: 0.1,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: 0.3,
      ),
    );
  }
}

/// Semantic colours and surfaces that are not part of [ColorScheme].
/// Kept as named getters so screens read `theme.successColor` instead of
/// guessing a hex value.
extension AppThemeX on ThemeData {
  AppPalette get palette =>
      extension<AppPalette>() ??
      (brightness == Brightness.dark ? AppPalette.dark : AppPalette.light);

  /// Green — a dose that was taken.
  Color get successColor => palette.success;

  /// Soft green block background.
  Color get successContainer => palette.successContainer;

  /// Amber — pending / snoozed / due soon.
  Color get pendingColor => palette.warning;

  /// Red — missed (Material's error role, so alerts stay consistent).
  Color get missedColor => colorScheme.error;

  /// Coral accent used sparingly for "act now" (due-now ring, active filter).
  Color get accentColor => brightness == Brightness.dark
      ? const Color(0xFFFF9F9F)
      : const Color(0xFFD14343);

  /// Tinted block behind the accent.
  Color get accentContainer => brightness == Brightness.dark
      ? const Color(0xFF482021)
      : const Color(0xFFFCE7E6);

  /// Calm teal block — the resting "next medicine" hero.
  Color get doseGradient => colorScheme.primary;

  /// Urgent red block — the hero when a dose is due now or overdue.
  Color get doseDueGradient => missedColor;

  /// 1px hairline used for cards, list rows and dividers.
  Color get cardBorder => palette.cardBorder;
}
