import 'package:flutter/material.dart';

import '../../core/levels/level_id.dart';
import '../levels/level_id_ui.dart';
import 'hub_selection_card_frame.dart';
import 'level_parallax_preview.dart';
import 'menu_button.dart';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LEVEL SELECTION',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 2,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            levelId.displayName.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 2,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            runTypeLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 2,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
