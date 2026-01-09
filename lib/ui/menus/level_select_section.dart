import 'package:flutter/material.dart';

import '../../core/levels/level_id.dart';
import '../levels/level_id_ui.dart';

class LevelSelectSection extends StatelessWidget {
  const LevelSelectSection({super.key, required this.onStartLevel});

  final void Function(LevelId levelId) onStartLevel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Level Selection',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => onStartLevel(LevelId.defaultLevel),
          child: Text(LevelId.defaultLevel.displayName),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => onStartLevel(LevelId.forest),
          child: Text(LevelId.forest.displayName),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => onStartLevel(LevelId.field),
          child: Text(LevelId.field.displayName),
        ),
      ],
    );
  }
}
