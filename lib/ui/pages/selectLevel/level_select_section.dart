import 'package:flutter/material.dart';

import 'package:runner_core/levels/level_id.dart';
import '../../levels/level_id_ui.dart';
import 'level_card.dart';

class LevelSelectSection extends StatelessWidget {
  const LevelSelectSection({
    super.key,
    required this.selectedLevelId,
    required this.onSelectLevel,
  });

  final LevelId selectedLevelId;
  final ValueChanged<LevelId> onSelectLevel;

  @override
  Widget build(BuildContext context) {
    final levels = selectableLevelIdsForUi();
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        for (final levelId in levels)
          LevelCard(
            levelId: levelId,
            selected: levelId == selectedLevelId,
            width: 200,
            onTap: () => onSelectLevel(levelId),
          ),
      ],
    );
  }
}
