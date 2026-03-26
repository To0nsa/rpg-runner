import 'package:flutter/material.dart';

import '../theme/ui_tokens.dart';

/// A scaffold wrapper for menu pages with consistent theme-token styling.
///
/// Handles:
/// - Optional full-page background behind content
/// - Optional AppBar with back button
/// - SafeArea for content
///
/// Use this for all menu pages to maintain consistency and DRY principles.
class MenuScaffold extends StatelessWidget {
  const MenuScaffold({
    super.key,
    required this.child,
    this.background,
    this.title,
    this.appBarTitle,
    this.centerAppBarTitle = false,
    this.showAppBar = true,
    this.useBodySafeArea = false,
  });

  /// The main content of the page.
  final Widget child;

  /// Full-page background rendered behind [child].
  /// If omitted, a default background image is used.
  final Widget? background;

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

  /// Whether to wrap the body in [SafeArea]. Defaults to false.
  final bool useBodySafeArea;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final topPadding = MediaQuery.paddingOf(context).top;
    final resolvedTitle =
        appBarTitle ??
        (title != null
            ? Text(title!, style: ui.text.title)
            : null);
    final appBarWidget = AppBar(
      title: resolvedTitle,
      backgroundColor: ui.colors.background,
      iconTheme: IconThemeData(color: ui.colors.textPrimary),
      primary: false,
      centerTitle: centerAppBarTitle,
      titleSpacing: appBarTitle != null ? 0 : null,
    );

    final bodyContent = useBodySafeArea
        ? SafeArea(maintainBottomViewPadding: true, child: child)
        : child;

    final resolvedBackground =
        background ??
        Image.asset(
          'assets/images/backgrounds/playHub_bgDark.png',
          fit: BoxFit.fitWidth,
          alignment: Alignment.bottomCenter,
        );

    final body = Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: resolvedBackground),
        bodyContent,
      ],
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
      body: body,
    );
  }
}
