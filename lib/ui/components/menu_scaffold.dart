import 'package:flutter/material.dart';

/// A scaffold wrapper for menu pages with consistent black/white styling.
///
/// Handles:
/// - Black background
/// - Optional AppBar with back button
/// - SafeArea for content
///
/// Use this for all menu pages to maintain consistency and DRY principles.
class MenuScaffold extends StatelessWidget {
  const MenuScaffold({
    super.key,
    required this.child,
    this.title,
    this.showAppBar = true,
  });

  /// The main content of the page.
  final Widget child;

  /// Optional title for the AppBar. If null, no title is shown.
  final String? title;

  /// Whether to show the AppBar with back button. Defaults to true.
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: showAppBar
          ? AppBar(
              title: title != null
                  ? Text(title!, style: const TextStyle(color: Colors.white))
                  : null,
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white),
            )
          : null,
      body: SafeArea(child: child),
    );
  }
}
