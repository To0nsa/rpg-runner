import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/levels/level_id.dart';
import '../components/menu_scaffold.dart';
import '../runner_game_route.dart';
import 'level_select_section.dart';

/// Level selection page with level cards in a row.
class RunnerMenuPage extends StatelessWidget {
  const RunnerMenuPage({super.key});

  void _startLevel(BuildContext context, LevelId levelId) {
    final seed = Random().nextInt(1 << 31);
    Navigator.of(context).push(
      createRunnerGameRoute(
        seed: seed,
        levelId: levelId,
        restoreOrientations: const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuScaffold(
      title: 'Select Level',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: LevelSelectSection(
              onStartLevel: (levelId) => _startLevel(context, levelId),
            ),
          ),
        ),
      ),
    );
  }
}
