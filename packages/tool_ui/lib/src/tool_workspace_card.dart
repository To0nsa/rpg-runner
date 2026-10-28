import 'package:flutter/material.dart';

import 'tool_ui_tokens.dart';

/// Canonical outer surface for a full editor route workspace.
///
/// The surface provides consistent outline and padding while leaving all
/// sizing, scrolling, and state ownership to its [child].
class ToolWorkspaceCard extends StatelessWidget {
  const ToolWorkspaceCard({
    super.key,
    required this.child,
    this.padding = ToolUiTokens.workspaceInsets,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}
