import 'package:flutter/material.dart';

import '../../core/levels/level_id.dart';

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
          child: const Text('Default'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => onStartLevel(LevelId.forest),
          child: const Text('Forest'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => onStartLevel(LevelId.field),
          child: const Text('Field'),
        ),
      ],
    );
  }
}

