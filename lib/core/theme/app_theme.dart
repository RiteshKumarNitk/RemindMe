import 'package:flutter/material.dart';

/// Material 3 theme tuned for elderly users: high contrast, generous type
/// sizes, large touch targets, calm colors.
class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF00696D);
  static const Color _seedDark = Color(0xFF6FD8DD);

  static ThemeData light() => _base(
    ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
      surface: const Color(0xFFFFFBF8),
      error: const Color(0xFFBA1A1A),
    ),
  );

  static ThemeData dark() => _base(
    ColorScheme.fromSeed(
      seedColor: _seedDark,
      brightness: Brightness.dark,
      surface: const Color(0xFF101415),
    ),
  );

  static ThemeData _base(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = _textTheme(base.textTheme);

    final filledStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(64)),
      textStyle: WidgetStatePropertyAll(
        text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    );

    final outlinedStyle = filledStyle.copyWith(
      side: WidgetStatePropertyAll(
        BorderSide(color: scheme.primary, width: 2.5),
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: filledStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedStyle),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(56, 56)),
          iconSize: const WidgetStatePropertyAll(28),
          visualDensity: VisualDensity.standard,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 84,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(size: 30, color: scheme.onSurfaceVariant),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      switchTheme: SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        labelStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: text.bodyLarge?.copyWith(color: scheme.outline),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: text.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: text.bodyLarge?.copyWith(color: scheme.onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyLarge?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.4),
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
    );
  }

  static TextTheme _textTheme(TextTheme base) => base.copyWith(
    displaySmall: base.displaySmall?.copyWith(
      fontSize: 40,
      fontWeight: FontWeight.w800,
      height: 1.15,
    ),
    headlineLarge: base.headlineLarge?.copyWith(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontSize: 21,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: base.titleSmall?.copyWith(fontSize: 18),
    bodyLarge: base.bodyLarge?.copyWith(fontSize: 19, height: 1.4),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 17, height: 1.4),
    bodySmall: base.bodySmall?.copyWith(fontSize: 15),
    labelLarge: base.labelLarge?.copyWith(fontSize: 18),
    labelMedium: base.labelMedium?.copyWith(fontSize: 16),
  );
}

/// Semantic colors that are not part of ColorScheme.
extension AppThemeX on ThemeData {
  /// Green used for "taken".
  Color get successColor => brightness == Brightness.dark
      ? const Color(0xFF81C784)
      : const Color(0xFF1B5E20);

  /// Amber used for "pending / snoozed".
  Color get pendingColor => brightness == Brightness.dark
      ? const Color(0xFFFFC857)
      : const Color(0xFF8A5A00);

  Color get missedColor => colorScheme.error;
}
