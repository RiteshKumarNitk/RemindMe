import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';

/// Visual weight of an action.
///
/// Every screen should have exactly **one** [AppButtonTone.primary] action —
/// the thing the user is most likely to want to do next.
enum AppButtonTone {
  /// Solid, filled. The single most important action on a screen.
  primary,

  /// Outlined + neutral. A real action, but not the loudest thing on screen.
  secondary,

  /// Solid red. Destructive actions only (delete, pause all, delete account).
  danger,

  /// Text-only, no border. Lowest emphasis (skip, cancel, "I'll take it later").
  quiet,

  /// Solid in an explicit colour — used on coloured/alarm surfaces where the
  /// brand palette would have no contrast.
  onColor,
}

/// The one button widget used across the app.
///
/// Big by default (60pt tall, full width) because the target user is elderly:
/// a tap must be easy to land without precision.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = AppButtonTone.primary,
    this.icon,
    this.height,
    this.expand = true,
    this.busy = false,
    this.foreground,
    this.background,
    this.tooltip,
  });

  /// Convenience constructors keep call sites short and consistent.
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height,
    this.expand = true,
    this.busy = false,
  }) : tone = AppButtonTone.primary,
       foreground = null,
       background = null,
       tooltip = null;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height,
    this.expand = true,
    this.busy = false,
  }) : tone = AppButtonTone.secondary,
       foreground = null,
       background = null,
       tooltip = null;

  const AppButton.quiet({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height,
    this.expand = true,
    this.busy = false,
  }) : tone = AppButtonTone.quiet,
       foreground = null,
       background = null,
       tooltip = null;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonTone tone;
  final IconData? icon;

  /// Defaults per tone (see [AppSizes]).
  final double? height;
  final bool expand;
  final bool busy;

  /// Explicit colours — only used with [AppButtonTone.onColor].
  final Color? foreground;
  final Color? background;
  final String? tooltip;

  double get _height =>
      height ?? (tone == AppButtonTone.primary ? AppSizes.button : AppSizes.button);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveHeight = height ?? _height;
    final enabled = onPressed != null && !busy;

    final Widget child = busy
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: _spinnerColor(theme),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSizes.iconMd),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final shape = RoundedRectangleBorder(
      borderRadius: AppRadius.controlRadius,
    );
    // Note: no `maximumSize` here. An infinite max width would make the button
    // demand infinite width whenever it sits in an unbounded parent (a Row),
    // which throws during layout. Full width is forced by the SizedBox below
    // instead, and a bare button simply sizes to its content.
    final baseStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, effectiveHeight)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      shape: WidgetStatePropertyAll(shape),
      textStyle: WidgetStatePropertyAll(
        theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: tone == AppButtonTone.primary ? 17 : 16,
        ),
      ),
    );

    final Widget button = switch (tone) {
      AppButtonTone.primary => FilledButton(
        style: baseStyle,
        onPressed: enabled ? onPressed : null,
        child: child,
      ),
      AppButtonTone.danger => FilledButton(
        style: baseStyle.copyWith(
          backgroundColor: WidgetStatePropertyAll(theme.colorScheme.error),
          foregroundColor: WidgetStatePropertyAll(theme.colorScheme.onError),
        ),
        onPressed: enabled ? onPressed : null,
        child: child,
      ),
      AppButtonTone.secondary => OutlinedButton(
        style: baseStyle.copyWith(
          side: WidgetStatePropertyAll(
            BorderSide(color: theme.cardBorder, width: 1.5),
          ),
          foregroundColor: WidgetStatePropertyAll(theme.colorScheme.onSurface),
        ),
        onPressed: enabled ? onPressed : null,
        child: child,
      ),
      AppButtonTone.quiet => TextButton(
        style: baseStyle.copyWith(
          foregroundColor: WidgetStatePropertyAll(theme.colorScheme.primary),
        ),
        onPressed: enabled ? onPressed : null,
        child: child,
      ),
      AppButtonTone.onColor => FilledButton(
        style: baseStyle.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? (background ?? Colors.white).withValues(alpha: 0.5)
                : (background ?? Colors.white),
          ),
          foregroundColor: WidgetStatePropertyAll(
            foreground ?? theme.colorScheme.primary,
          ),
        ),
        onPressed: enabled ? onPressed : null,
        child: child,
      ),
    };

    final sized = expand
        ? SizedBox(width: double.infinity, height: effectiveHeight, child: button)
        : SizedBox(height: effectiveHeight, child: button);

    return tooltip == null ? sized : Tooltip(message: tooltip!, child: sized);
  }

  Color? _spinnerColor(ThemeData theme) => switch (tone) {
    AppButtonTone.onColor => foreground ?? theme.colorScheme.primary,
    AppButtonTone.danger => theme.colorScheme.onError,
    AppButtonTone.primary => theme.colorScheme.onPrimary,
    _ => theme.colorScheme.primary,
  };
}

/// Small, square, labelled icon action (e.g. the header bell / avatar).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.badge = false,
    this.filled = true,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  /// Shows a small red dot — used for "reminders need attention".
  final bool badge;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = filled
        ? IconButton.filledTonal(
            onPressed: onPressed,
            tooltip: semanticLabel,
            icon: Icon(icon, size: AppSizes.iconLg),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainer,
              foregroundColor: theme.colorScheme.onSurface,
              minimumSize: const Size(AppSizes.tapTarget, AppSizes.tapTarget),
            ),
          )
        : IconButton(
            onPressed: onPressed,
            tooltip: semanticLabel,
            icon: Icon(icon, size: AppSizes.iconLg),
          );

    if (!badge) return button;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          right: 6,
          top: 6,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: theme.colorScheme.error,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
