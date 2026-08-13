import 'package:flutter/widgets.dart';

import '../../../shared/editor_three_panel_layout.dart';
import '../../../shared/editor_ui_tokens.dart';

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
  Widget build(BuildContext context) => EditorThreePanelLayout(
    firstLabel: 'Owners',
    secondLabel: 'Scene',
    thirdLabel: 'Shapes',
    first: inspector,
    second: scene,
    third: display,
    gap: EditorUiTokens.panelGap,
  );
}
