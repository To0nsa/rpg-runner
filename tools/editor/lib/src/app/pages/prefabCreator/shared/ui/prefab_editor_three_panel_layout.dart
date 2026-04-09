import 'package:flutter/widgets.dart';

import 'prefab_editor_ui_tokens.dart';

/// Shared `1:2:1` shell used by prefab-editor tabs.
class PrefabEditorThreePanelLayout extends StatelessWidget {
  const PrefabEditorThreePanelLayout({
    super.key,
    required this.inspector,
    required this.scene,
    required this.display,
  });

  final Widget inspector;
  final Widget scene;
  final Widget display;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 1, child: inspector),
        const SizedBox(width: PrefabEditorUiTokens.panelGap),
        Expanded(flex: 2, child: scene),
        const SizedBox(width: PrefabEditorUiTokens.panelGap),
        Expanded(flex: 1, child: display),
      ],
    );
  }
}
