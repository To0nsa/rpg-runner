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
    this.drawAppBarOverBackground = true,
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

  /// Whether the AppBar should overlay the background image.
  ///
  /// When enabled, the background extends behind the AppBar and body content
  /// is offset to remain below the toolbar. Defaults to true.
  final bool drawAppBarOverBackground;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    Widget? resolvedTitle = appBarTitle;
    if (resolvedTitle == null && title != null) {
      resolvedTitle = Text(title!, style: ui.text.title);
    }

    final shouldOverlayAppBar = showAppBar && drawAppBarOverBackground;
    final scaffoldAppBar = showAppBar
        ? AppBar(
            title: resolvedTitle,
            backgroundColor: shouldOverlayAppBar
                ? Colors.transparent
                : ui.colors.background,
            surfaceTintColor: shouldOverlayAppBar ? Colors.transparent : null,
            shadowColor: shouldOverlayAppBar ? Colors.transparent : null,
            elevation: shouldOverlayAppBar ? 0 : null,
            scrolledUnderElevation: shouldOverlayAppBar ? 0 : null,
            iconTheme: IconThemeData(color: ui.colors.textPrimary),
            centerTitle: centerAppBarTitle,
            titleSpacing: appBarTitle != null ? 0 : null,
          )
        : null;

    Widget content = useBodySafeArea
        ? SafeArea(maintainBottomViewPadding: true, child: child)
        : child;

    if (shouldOverlayAppBar) {
      content = Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + kToolbarHeight,
        ),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: ui.colors.background,
      extendBodyBehindAppBar: shouldOverlayAppBar,
      appBar: scaffoldAppBar,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child:
                background ??
                Image.asset(
                  'assets/images/backgrounds/playHub_bgDark.png',
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.bottomCenter,
                ),
          ),
          content,
        ],
      ),
    );
  }
}
