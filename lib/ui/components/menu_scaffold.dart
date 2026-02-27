import 'package:flutter/material.dart';

import '../theme/ui_tokens.dart';

/// A scaffold wrapper for menu pages with consistent theme-token styling.
///
/// Handles:
/// - Brand background
/// - Optional AppBar with back button
/// - SafeArea for content
///
/// Use this for all menu pages to maintain consistency and DRY principles.
class MenuScaffold extends StatelessWidget {
  const MenuScaffold({
    super.key,
    required this.child,
    this.title,
    this.appBarTitle,
    this.centerAppBarTitle = false,
    this.showAppBar = true,
  });

  /// The main content of the page.
  final Widget child;

  /// Optional title for the AppBar. If null, no title is shown.
  final String? title;

  /// Optional custom title widget for the AppBar (e.g. a segmented control).
  ///
  /// If provided, this takes precedence over [title].
  final Widget? appBarTitle;

  /// Whether the AppBar title should be centered.
  ///
  /// Useful when [appBarTitle] is a compact widget (e.g. segmented control)
  /// that should be visually centered in the toolbar.
  final bool centerAppBarTitle;

  /// Whether to show the AppBar with back button. Defaults to true.
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final topPadding = MediaQuery.paddingOf(context).top;
    final resolvedTitle =
        appBarTitle ??
        (title != null
            ? Text(
                title!,
                style: ui.text.title.copyWith(
                  color: ui.colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null);
    final appBarWidget = AppBar(
      title: resolvedTitle,
      backgroundColor: ui.colors.background,
      iconTheme: IconThemeData(color: ui.colors.textPrimary),
      // We provide our own SafeArea so all menu pages share one safe-area
      // policy from the app shell MediaQuery configuration.
      primary: false,
      centerTitle: centerAppBarTitle,
      titleSpacing: appBarTitle != null ? 0 : null,
    );

    return Scaffold(
      backgroundColor: ui.colors.background,
      appBar: showAppBar
          ? PreferredSize(
              preferredSize: Size.fromHeight(
                topPadding + appBarWidget.preferredSize.height,
              ),
              child: SafeArea(bottom: false, child: appBarWidget),
            )
          : null,
      body: SafeArea(maintainBottomViewPadding: true, child: child),
    );
  }
}
