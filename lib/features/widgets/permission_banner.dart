import 'package:flutter/material.dart';

/// Full-width banner asking the user to grant a permission. Only rendered
/// when [show] is true.
class PermissionBanner extends StatelessWidget {
  const PermissionBanner({
    super.key,
    required this.show,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
    this.icon = Icons.notifications_active_rounded,
  });

  final bool show;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 30, color: theme.colorScheme.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                minimumSize: const Size.fromHeight(56),
                textStyle: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: onPressed,
              icon: const Icon(Icons.settings_rounded, size: 26),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
