import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import 'app_buttons.dart';

/// Designed empty state — never "No data found".
///
/// Every empty state explains what will appear here and, where it makes sense,
/// offers the single action that creates it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Compact variant for an empty *section* inside a longer screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: compact ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Container(
            width: compact ? 72 : 96,
            height: compact ? 72 : 96,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: compact ? 34 : 44,
              color: theme.colorScheme.primary,
            ),
          ),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: AppButton(
                label: actionLabel!,
                icon: Icons.add_rounded,
                onPressed: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Friendly failure state. The message is written for the user, in their
/// language, with no exception text and one obvious way to recover.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.retryLabel,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  final String title;
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: AppButton.secondary(
                  label: retryLabel ?? 'Try again',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Placeholder blocks shown while data loads.
///
/// Preferred over a bare spinner: the layout does not jump when content
/// arrives, and the page still reads as *this* screen.
class SkeletonList extends StatefulWidget {
  const SkeletonList({
    super.key,
    this.rows = 3,
    this.rowHeight = 76,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
  });

  final int rows;
  final double rowHeight;
  final EdgeInsetsGeometry padding;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = Color.lerp(
          theme.colorScheme.surfaceContainer,
          theme.colorScheme.surfaceContainerHigh,
          _controller.value,
        );
        return Padding(
          padding: widget.padding,
          child: Column(
            children: [
              for (var i = 0; i < widget.rows; i++) ...[
                Container(
                  height: widget.rowHeight,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: AppRadius.cardRadius,
                  ),
                ),
                if (i != widget.rows - 1) const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A single skeleton block (for headers / hero placeholders).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height = 120, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: AppRadius.cardRadius,
      ),
    );
  }
}
