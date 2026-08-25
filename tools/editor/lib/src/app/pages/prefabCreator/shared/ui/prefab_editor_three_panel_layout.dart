import 'package:flutter/widgets.dart';

import '../../../shared/editor_ui_tokens.dart';

/// Scene-preserving responsive shell used by Prefab editor workspaces.
///
/// Wide windows use the established `1:2:1` split. Narrow windows keep the
/// scene visible above the two independently scrollable sidebars instead of
/// replacing panels with tabs. Global keys retain all three subtrees while a
/// live window crosses the responsive breakpoint.
class PrefabEditorThreePanelLayout extends StatefulWidget {
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
  State<PrefabEditorThreePanelLayout> createState() =>
      _PrefabEditorThreePanelLayoutState();
}

class _PrefabEditorThreePanelLayoutState
    extends State<PrefabEditorThreePanelLayout> {
  static const double _minimumWideWidth = 1100;
  final GlobalKey _inspectorKey = GlobalKey(debugLabel: 'prefab_inspector');
  final GlobalKey _sceneKey = GlobalKey(debugLabel: 'prefab_scene');
  final GlobalKey _displayKey = GlobalKey(debugLabel: 'prefab_display');

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= _minimumWideWidth) {
        return Row(
          key: const ValueKey<String>('editor_three_panel_wide'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: _inspector()),
            const SizedBox(width: EditorUiTokens.panelGap),
            Expanded(flex: 2, child: _scene()),
            const SizedBox(width: EditorUiTokens.panelGap),
            Expanded(child: _display()),
          ],
        );
      }

      return Column(
        key: const ValueKey<String>('editor_three_panel_narrow'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(flex: 3, child: _scene()),
          const SizedBox(height: EditorUiTokens.panelGap),
          Expanded(
            flex: 2,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: _inspector()),
                const SizedBox(width: EditorUiTokens.panelGap),
                Expanded(child: _display()),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _inspector() =>
      KeyedSubtree(key: _inspectorKey, child: widget.inspector);

  Widget _scene() => KeyedSubtree(key: _sceneKey, child: widget.scene);

  Widget _display() => KeyedSubtree(key: _displayKey, child: widget.display);
}
