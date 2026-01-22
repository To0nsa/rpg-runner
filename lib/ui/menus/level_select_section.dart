import 'package:flutter/material.dart';

import '../../core/levels/level_id.dart';
import '../components/level_card.dart';

/// Level selection section displaying level cards in a row.
class LevelSelectSection extends StatelessWidget {
  const LevelSelectSection({super.key, required this.onStartLevel});

  final void Function(LevelId levelId) onStartLevel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LevelCard(
            levelId: LevelId.field,
            onTap: () => onStartLevel(LevelId.field),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: LevelCard(
            levelId: LevelId.forest,
            onTap: () => onStartLevel(LevelId.forest),
          ),
        ),
      ],
    );
  }
}
