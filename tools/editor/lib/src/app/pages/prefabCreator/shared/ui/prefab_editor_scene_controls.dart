import 'package:flutter/material.dart';

import 'prefab_editor_ui_tokens.dart';

/// Shared scene-control strip for prefab-editor scene widgets.
class PrefabEditorSceneControls extends StatelessWidget {
  const PrefabEditorSceneControls({
    super.key,
    required this.zoomControls,
    this.width,
    this.bottom,
  });

  final Widget zoomControls;
  final double? width;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    Widget topRow = Row(
      children: [
        const Spacer(),
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: zoomControls,
          ),
        ),
      ],
    );

    if (width != null) {
      topRow = SizedBox(width: width, child: topRow);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        topRow,
        if (bottom != null) ...[
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          bottom!,
        ],
      ],
    );
  }
}
