import 'package:game_presentation/enemy_text.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:runner_core/enemies/enemy_id.dart';

import '../../codex/codex_catalog.dart';
import '../../components/app_button.dart';
import '../../components/app_dialog.dart';
import '../../components/enemy_portrait.dart';
import '../../theme/ui_tokens.dart';

/// Presents eligible opponents. Selecting None calls [onSelected] with null;
/// closing the dialog leaves the current choice unchanged.
class TrainingOpponentDialog extends StatelessWidget {
  const TrainingOpponentDialog({
    super.key,
    required this.enemies,
    required this.selectedEnemy,
    required this.onSelected,
  });

  final Iterable<EnemyId> enemies;
  final EnemyId? selectedEnemy;
  final ValueChanged<EnemyId?> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return AppDialog(
      title: context.l10n.uiTrainingOpponent,
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.uiChooseAnOpponentForYourNextFight,
            style: ui.text.body.copyWith(color: ui.colors.textMuted),
          ),
          SizedBox(height: ui.space.sm),
          _OpponentTile(
            enemy: null,
            selected: selectedEnemy == null,
            onTap: () => onSelected(null),
          ),
          for (final enemy in enemies)
            Padding(
              padding: EdgeInsets.only(top: ui.space.xs),
              child: _OpponentTile(
                enemy: enemy,
                selected: selectedEnemy == enemy,
                onTap: () => onSelected(enemy),
              ),
            ),
          if (enemies.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: ui.space.sm),
              child: Text(
                context
                    .l10n
                    .uiUnlockEnemyEntriesInTheLibraryToPractiseAgainstThem,
                style: ui.text.body.copyWith(color: ui.colors.textMuted),
              ),
            ),
        ],
      ),
      actions: [
        AppButton(
          label: context.l10n.uiClose,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.xs,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _OpponentTile extends StatelessWidget {
  const _OpponentTile({
    required this.enemy,
    required this.selected,
    required this.onTap,
  });

  final EnemyId? enemy;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final border = selected ? ui.colors.accentStrong : ui.colors.outline;
    final radius = BorderRadius.circular(ui.radii.sm);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? ui.colors.background : ui.colors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(ui.space.xs),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: ui.colors.background,
                    borderRadius: radius,
                    border: Border.all(color: border),
                  ),
                  child: enemy == null
                      ? Icon(Icons.block_outlined, color: ui.colors.textMuted)
                      : EnemyPortrait(enemy: enemy!),
                ),
                SizedBox(width: ui.space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enemy == null
                            ? context.l10n.uiNone
                            : enemyDisplayName(
                                enemy!,
                                strings: context.gameL10n,
                              ),
                        style: ui.text.headline.copyWith(
                          color: ui.colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: ui.space.xxs),
                      Text(
                        enemy == null
                            ? context.l10n.uiPractiseWithoutAnOpponent
                            : CodexCatalog.enemyTactics(enemy!, context.l10n),
                        style: ui.text.body.copyWith(
                          color: ui.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: ui.space.xs),
                ExcludeSemantics(
                  child: Icon(
                    selected ? Icons.check_circle_outline : Icons.chevron_right,
                    color: selected
                        ? ui.colors.accentStrong
                        : ui.colors.textMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
