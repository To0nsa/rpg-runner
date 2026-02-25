import 'package:flutter/material.dart';

import 'menu_layout.dart';
import 'menu_scaffold.dart';
import '../theme/ui_tokens.dart';

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
    final ui = context.ui;
    return MenuScaffold(
      title: title,
      child: MenuLayout(
        alignment: Alignment.center,
        scrollable: false,
        child: Text(
          message,
          style: ui.text.title.copyWith(color: ui.colors.textMuted),
        ),
      ),
    );
  }
}
