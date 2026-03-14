import 'package:flutter/material.dart';

import 'package:runner_core/levels/level_id.dart';
import 'level_card.dart';

class LevelSelectSection extends StatelessWidget {
  const LevelSelectSection({
    super.key,
    required this.selectedLevelId,
    required this.onSelectLevel,
    this.forcedLevelId,
  });

  final LevelId selectedLevelId;
  final ValueChanged<LevelId> onSelectLevel;
  final LevelId? forcedLevelId;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        for (final levelId in LevelId.values)
          Builder(
            builder: (context) {
              final forced = forcedLevelId;
              final selectable = forced == null || forced == levelId;
              final effectiveSelected = forced ?? selectedLevelId;
              return LevelCard(
                levelId: levelId,
                selected: levelId == effectiveSelected,
                width: 200,
                onTap: selectable ? () => onSelectLevel(levelId) : null,
              );
            },
          ),
      ],
    );
  }
}
