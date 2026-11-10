import 'package:rpg_runner/ui/l10n/app_localization.dart';
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
              LevelBlessingId.regeneration =>
                context.l10n.regenerationBlessingSemantics,
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
                            ? context.l10n.regenerationIncreased
                            : context.l10n.forestBlessingName,
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
