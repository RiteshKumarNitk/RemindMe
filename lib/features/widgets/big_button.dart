import 'package:flutter/material.dart';

import 'app_buttons.dart';

/// Backwards-compatible wrapper around [AppButton].
///
/// Kept because a dozen screens already speak this API; new code should use
/// [AppButton] directly, which exposes tones (primary / secondary / danger /
/// quiet) instead of a single `outlined` flag.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 60,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      icon: icon,
      height: height,
      onPressed: onPressed,
      tone: outlined ? AppButtonTone.secondary : AppButtonTone.primary,
    );
  }
}

/// Quiet full-width text action (Skip / Not now).
class BigTextButton extends StatelessWidget {
  const BigTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      icon: icon,
      tone: AppButtonTone.quiet,
      height: 56,
      onPressed: onPressed,
    );
  }
}
