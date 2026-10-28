import 'package:flutter/material.dart';

import 'package:tool_ui/tool_ui.dart';

/// Lightweight intro card used by editor routes that expose explanatory copy.
///
/// This keeps title/description presentation consistent without introducing a
/// route-specific scaffold dependency.
class EditorRouteIntroCard extends StatelessWidget {
  const EditorRouteIntroCard({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) =>
      ToolPanelCard(title: title, child: Text(description));
}
