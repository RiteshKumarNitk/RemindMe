import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// Short branded loading screen shown while the app initialises.
///
/// Deliberately still: a calm logo and a thin progress line. No pulsing, no
/// gradients — a splash should reassure, not perform.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Image.asset(
                  'assets/dosewise_logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.medication_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('DoseWise', style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
