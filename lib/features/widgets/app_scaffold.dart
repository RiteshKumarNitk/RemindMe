import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// Standard screen frame.
///
/// Gives every screen the same margins, the same page title typography and the
/// same bottom clearance for the floating navigation bar, so no screen has to
/// invent its own layout numbers.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions = const [],
    this.showAppBar = true,
    this.leading,
    this.scrollable = true,
    this.padding,
    this.bottomClearance = 0,
    this.floatingAction,
    this.onRefresh,
  });

  final String title;
  final List<Widget> children;
  final String? subtitle;
  final List<Widget> actions;
  final bool showAppBar;
  final Widget? leading;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;

  /// Extra space below the content (tab screens sit above the nav bar).
  final double bottomClearance;
  final Widget? floatingAction;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final body = scrollable
        ? ListView(
            padding: (padding ?? AppSpacing.page).add(
              EdgeInsets.only(bottom: bottomClearance),
            ),
            children: children,
          )
        : Padding(
            padding: padding ?? AppSpacing.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          );

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
              leading: leading,
              actions: actions,
            )
          : null,
      body: SafeArea(bottom: false, child: body),
      floatingActionButton: floatingAction,
    );
  }
}

/// Page title block used by the tab screens (which have no AppBar).
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
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
        for (final w in trailing) ...[const SizedBox(width: AppSpacing.xs), w],
      ],
    );
  }
}
