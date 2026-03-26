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
    Widget? resolvedTitle = appBarTitle;
    if (resolvedTitle == null && title != null) {
      resolvedTitle = Text(title!, style: ui.text.title);
    }

    final scaffoldAppBar = showAppBar
        ? AppBar(
            title: resolvedTitle,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: IconThemeData(color: ui.colors.textPrimary),
            centerTitle: centerAppBarTitle,
            titleSpacing: appBarTitle != null ? 0 : null,
          )
        : null;

    Widget content = useBodySafeArea
        ? SafeArea(maintainBottomViewPadding: true, child: child)
        : child;

    if (showAppBar) {
      content = Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + kToolbarHeight,
        ),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: ui.colors.background,
      extendBodyBehindAppBar: showAppBar,
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
