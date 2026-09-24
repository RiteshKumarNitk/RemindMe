import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';

/// A plain surface block: 1px hairline border, small radius, no shadow.
///
/// Cards group *related* content — never decoration. A simple list of equal
/// items should use [AppListRow]s inside one card rather than one card each.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color,
    this.borderColor,
    this.onTap,
    this.radius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = radius ?? AppRadius.cardRadius;
    return Material(
      color: color ?? theme.colorScheme.surface,
      borderRadius: shape,
      child: InkWell(
        onTap: onTap,
        borderRadius: shape,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(
              color: borderColor ?? theme.cardBorder,
              width: 1.5,
            ),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Horizontal rule + spacing used to separate blocks. Deliberately subtle.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: indent),
    child: Divider(height: 1, thickness: 1, color: Theme.of(context).cardBorder),
  );
}

/// Section heading: reads as a title, optionally with a trailing action.
/// One per content block — never used for a single field.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: AppSizes.iconMd, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// The visual "tone" of a [AppInfoNote] / [AppListRow] leading bubble.
enum AppNoteTone { info, success, warning, danger, neutral }

extension AppNoteToneX on AppNoteTone {
  (Color fg, Color bg) colors(ThemeData theme) {
    final p = theme.palette;
    return switch (this) {
      AppNoteTone.info => (p.info, p.infoContainer),
      AppNoteTone.success => (p.success, p.successContainer),
      AppNoteTone.warning => (p.warning, p.warningContainer),
      AppNoteTone.danger => (theme.colorScheme.error, theme.colorScheme.errorContainer),
      AppNoteTone.neutral => (
        theme.colorScheme.onSurfaceVariant,
        p.neutralContainer,
      ),
    };
  }
}

/// Tinted, bordered message block with an icon — used for hints, warnings and
/// status. Colour is never the only signal: the icon and the wording carry the
/// meaning too.
class AppInfoNote extends StatelessWidget {
  const AppInfoNote({
    super.key,
    required this.message,
    this.tone = AppNoteTone.info,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  final String message;
  final AppNoteTone tone;
  final String? title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  static IconData defaultIcon(AppNoteTone tone) => switch (tone) {
    AppNoteTone.info => Icons.info_outline_rounded,
    AppNoteTone.success => Icons.check_circle_rounded,
    AppNoteTone.warning => Icons.warning_amber_rounded,
    AppNoteTone.danger => Icons.error_outline_rounded,
    AppNoteTone.neutral => Icons.info_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (fg, bg) = tone.colors(theme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.controlRadius,
        border: Border.all(color: fg.withValues(alpha: 0.28), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon ?? defaultIcon(tone), color: fg, size: AppSizes.iconLg),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: theme.textTheme.titleMedium?.copyWith(color: fg),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                    ],
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButtonInline(
              label: actionLabel!,
              icon: actionIcon,
              onPressed: onAction!,
              color: fg,
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact in-note action that stays readable against a tinted background.
class AppButtonInline extends StatelessWidget {
  const AppButtonInline({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward_rounded, size: AppSizes.iconMd),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: c,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(AppSizes.tapTarget),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.controlRadius),
          textStyle: theme.textTheme.labelLarge,
        ),
      ),
    );
  }
}

/// A tappable row: leading bubble/icon, title, optional subtitle, trailing
/// control. The single building block for the medicines list, the settings
/// groups and the family screen.
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.dense = false,
    this.semanticLabel,
  });

  final String title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final bool dense;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: dense ? AppSpacing.sm : AppSpacing.md,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: titleColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  DefaultTextStyle.merge(
                    style: theme.textTheme.bodyMedium!,
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.xs),
            trailing!,
          ] else if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: AppSizes.iconLg,
              color: theme.colorScheme.outline,
            ),
        ],
      ),
    );

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardRadius,
          child: content,
        ),
      ),
    );
  }
}

/// Circular icon bubble used as the leading element of list rows and as the
/// status marker on timeline rows.
class AppIconBubble extends StatelessWidget {
  const AppIconBubble({
    super.key,
    required this.icon,
    required this.color,
    this.background,
    this.size = AppSizes.avatar,
  });

  final IconData icon;
  final Color color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}
