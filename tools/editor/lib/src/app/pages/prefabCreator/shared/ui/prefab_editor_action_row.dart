import 'package:flutter/widgets.dart';

import 'package:tool_ui/tool_ui.dart';

/// Shared wrapped action row for inspector controls.
class PrefabEditorActionRow extends StatelessWidget {
  const PrefabEditorActionRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ToolUiTokens.controlGap,
      runSpacing: ToolUiTokens.controlGap,
      children: children,
    );
  }
}
