import 'package:flutter/material.dart';
import 'package:runner_core/interactions/level_blessing.dart';

import '../../theme/ui_tokens.dart';

/// Persistent blessing feedback driven by snapshots; its initial message uses
/// simulation ticks so pausing or remounting never restarts a wall-clock timer.
class LevelBlessingsHud extends StatelessWidget {
  const LevelBlessingsHud({
    super.key,
    required this.blessings,
    required this.tick,
    required this.tickHz,
  });

  final List<LevelBlessingSnapshot> blessings;
  final int tick, tickHz;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final blessing in blessings)
          Semantics(
            label: switch (blessing.id) {
              LevelBlessingId.regeneration => 'Bénédiction des Dames de la forêt : régénération de santé, de mana et d’endurance augmentée jusqu’à la fin du niveau',
            },
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 14,
                    color: ui.colors.textPrimary,
                  ),
                  SizedBox(width: ui.space.xxs),
                  Text(
                    switch (blessing.id) {
                      LevelBlessingId.regeneration =>
                        tick - blessing.grantedAtTick < tickHz * 2
                            ? 'Regeneration increased'
                            : 'Bénédiction des Dames de la forêt',
                    },
                    style: ui.text.body.copyWith(
                      fontSize: 11,
                      color: ui.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
