import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import 'app_buttons.dart';

/// One confirmation pattern for every destructive or irreversible action.
///
/// The confirm button is always the destructive-looking one and always says
/// what it does ("Delete", "Pause all") — never a bare "OK".
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = true,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        icon: icon == null
            ? null
            : Icon(
                icon,
                size: AppSizes.iconXl,
                color: destructive
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
        title: Text(title),
        content: Text(message),
        actions: [
          AppButton.secondary(
            label: cancelLabel ?? MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            height: 52,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton(
            label: confirmLabel,
            tone: destructive
                ? AppButtonTone.danger
                : AppButtonTone.primary,
            height: 52,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsOverflowButtonSpacing: AppSpacing.xs,
        actionsOverflowAlignment: OverflowBarAlignment.center,
      );
    },
  );
  return result ?? false;
}

/// One action inside a [showAppActionSheet].
class AppSheetAction {
  const AppSheetAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.subtitle,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final String? subtitle;
  final bool destructive;
}

/// Contextual menu for a list row. Keeps rows uncluttered while every action
/// stays a full-width, 60pt tap target.
Future<void> showAppActionSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<AppSheetAction> actions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.md),
              for (final action in actions) ...[
                _SheetRow(
                  action: action,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    action.onSelected();
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.action, required this.onTap});

  final AppSheetAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = action.destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: AppRadius.controlRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.controlRadius,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.controlRadius,
            border: Border.all(color: theme.cardBorder, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(
                action.icon,
                size: AppSizes.iconLg,
                color: action.destructive
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.label,
                      style: theme.textTheme.titleMedium?.copyWith(color: color),
                    ),
                    if (action.subtitle != null)
                      Text(
                        action.subtitle!,
                        style: theme.textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only informational dialog with a single "Close" action.
Future<void> showAppInfoDialog(
  BuildContext context, {
  required String title,
  required Widget content,
  String? closeLabel,
  IconData? icon,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        icon: icon == null
            ? null
            : Icon(icon, size: AppSizes.iconXl, color: theme.colorScheme.primary),
        title: Text(title),
        content: SingleChildScrollView(child: content),
        actions: [
          AppButton.secondary(
            label: closeLabel ??
                MaterialLocalizations.of(dialogContext).closeButtonLabel,
            height: 52,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      );
    },
  );
}
