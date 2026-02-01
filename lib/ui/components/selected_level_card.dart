import 'package:flutter/material.dart';

import '../../core/levels/level_id.dart';
import '../levels/level_id_ui.dart';
import 'hub_selection_card_body.dart';
import 'hub_selection_card_frame.dart';
import 'level_parallax_preview.dart';

/// Hub card showing the currently selected level.
class SelectedLevelCard extends StatelessWidget {
  const SelectedLevelCard({
    super.key,
    required this.levelId,
    required this.runTypeLabel,
    required this.onChange,
    this.width = HubSelectionCardFrame.defaultWidth,
    this.height = HubSelectionCardFrame.defaultHeight,
  });

  final LevelId levelId;
  final String runTypeLabel;
  final VoidCallback onChange;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return HubSelectionCardFrame(
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      onTap: onChange,
      background: LevelParallaxPreview(
        themeId: levelId.themeId,
        alignment: Alignment.center,
      ),
      child: HubSelectionCardBody(
        headerText: 'LEVEL SELECTION',
        title: levelId.displayName.toUpperCase(),
        subtitle: runTypeLabel,
      ),
    );
  }
}
