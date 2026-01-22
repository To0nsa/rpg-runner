import 'package:flutter/material.dart';

import 'menu_scaffold.dart';

/// A reusable placeholder page for features not yet implemented.
///
/// Displays the page title and "Coming Soon" text with consistent styling.
/// Use this for any menu pages that are placeholders for future features.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    this.message = 'Coming Soon',
  });

  /// The title shown in the AppBar.
  final String title;

  /// The placeholder message shown in the center. Defaults to "Coming Soon".
  final String message;

  @override
  Widget build(BuildContext context) {
    return MenuScaffold(
      title: title,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 24,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}
