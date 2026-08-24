import 'package:flutter/material.dart';

/// Extra-large filled button for primary actions (e.g. "TAKE MEDICINE").
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 72,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size.fromHeight(height)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 30), const SizedBox(width: 12)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    if (outlined) {
      return OutlinedButton(style: style, onPressed: onPressed, child: child);
    }
    return FilledButton(style: style, onPressed: onPressed, child: child);
  }
}

/// Compact but still large text button (used for "Skip").
class BigTextButton extends StatelessWidget {
  const BigTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: Theme.of(context).textTheme.titleMedium,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
