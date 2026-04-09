import 'package:flutter/widgets.dart';

import 'prefab_editor_ui_tokens.dart';

/// Shared wrapped action row for inspector controls.
class PrefabEditorActionRow extends StatelessWidget {
  const PrefabEditorActionRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: PrefabEditorUiTokens.controlGap,
      runSpacing: PrefabEditorUiTokens.controlGap,
      children: children,
    );
  }
}
