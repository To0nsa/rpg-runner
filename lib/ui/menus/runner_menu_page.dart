import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/levels/level_id.dart';
import '../runner_game_route.dart';
import 'level_select_section.dart';

/// Development-only menu that will expand over time.
///
/// For now it only supports level selection and starting a run.
class RunnerMenuPage extends StatelessWidget {
  const RunnerMenuPage({super.key});

  void _startLevel(BuildContext context, LevelId levelId) {
    final seed = Random().nextInt(1 << 31);
    Navigator.of(context).push(
      createRunnerGameRoute(
        seed: seed,
        levelId: levelId,
        restoreOrientations: const [DeviceOrientation.portraitUp],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Runner Menu', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 6, 21, 48),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LevelSelectSection(
          onStartLevel: (levelId) => _startLevel(context, levelId),
        ),
      ),
    );
  }
}

