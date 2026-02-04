import 'package:flutter/material.dart';

/// A scaffold wrapper for menu pages with consistent black/white styling.
///
/// Handles:
/// - Black background
/// - Optional AppBar with back button
/// - SafeArea (top/bottom) for content
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
    final topPadding = MediaQuery.paddingOf(context).top;
    final resolvedTitle =
        appBarTitle ??
        (title != null
            ? Text(title!, style: const TextStyle(color: Colors.white))
            : null);
    final appBarWidget = AppBar(
      title: resolvedTitle,
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
      // We'll apply our own SafeArea so we can ignore transient horizontal
      // insets (e.g. Android nav bar) that can cause jitter.
      primary: false,
      centerTitle: centerAppBarTitle,
      titleSpacing: appBarTitle != null ? 0 : null,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: showAppBar
          ? PreferredSize(
              preferredSize: Size.fromHeight(
                topPadding + appBarWidget.preferredSize.height,
              ),
              child: SafeArea(
                left: false,
                right: false,
                bottom: false,
                child: appBarWidget,
              ),
            )
          : null,
      // Avoid horizontal "layout jitter" when transient system UI (e.g. the
      // Android navigation bar) briefly appears/disappears during keyboard and
      // focus transitions. Menu content already applies its own horizontal
      // padding via MenuLayout, and most menu pages are safe to treat as
      // horizontally full-bleed.
      body: SafeArea(
        left: false,
        right: false,
        maintainBottomViewPadding: true,
        child: child,
      ),
    );
  }
}
