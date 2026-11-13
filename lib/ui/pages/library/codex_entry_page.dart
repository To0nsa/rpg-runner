import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/levels/level_id.dart';

import '../../codex/codex_catalog.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app/app_state.dart';

import '../../theme/ui_bestiary_theme.dart';
import '../../theme/ui_tokens.dart';
import 'bestiary_entry_view.dart';
import 'codex_widgets.dart';

/// Rechecks the current account's gate even when an entry route is already open.
class CodexEntryPage extends StatelessWidget {
  const CodexEntryPage.enemy(EnemyId id, {super.key})
    : enemyId = id,
      levelId = null;
  const CodexEntryPage.level(LevelId id, {super.key})
    : levelId = id,
      enemyId = null;
  final EnemyId? enemyId;
  final LevelId? levelId;

  @override
  Widget build(BuildContext context) {
    if (levelId case final id?) {
      return MenuScaffold(
        title: CodexCatalog.levelName(id, context.l10n),
        background: ColoredBox(color: context.ui.colors.background),
        child: SafeArea(top: false, child: CodexLevelDetails(levelId: id)),
      );
    }
    final progress = context.watch<AppState>().progression;
    final enemy = CodexCatalog.parentBoss(enemyId!) ?? enemyId!;
    final unlocked = CodexCatalog.enemyUnlocked(progress.enemyDefeats, enemy);
    final current = progress.enemyDefeats.byEnemy[enemy.name] ?? 0;
    final target = CodexCatalog.killsRequired(enemy);
    return MenuScaffold(
      title: context.l10n.uiLibrary,
      background: ColoredBox(color: context.bestiary.background),
      child: SafeArea(
        top: false,
        child: unlocked
            ? BestiaryEntryView(enemy: enemy)
            : CodexReadingView(
                title: context.l10n.uiEntryLocked,
                subtitle: context.l10n.uiBestiary,
                paragraphs: [
                  context.l10n.codexUnlockEnemy(count: target),
                  context.l10n.codexDefeatedProgress(
                    current: current,
                    target: target,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Uses current account progress in both the Library map dialog and entry route.
class CodexLevelDetails extends StatelessWidget {
  const CodexLevelDetails({super.key, required this.levelId});

  final LevelId levelId;

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<AppState>().progression.codex;
    final title = CodexCatalog.levelName(levelId, context.l10n);
    final target = CodexCatalog.levelScoreRequirements[levelId]!;
    final current = progress.competitiveBestScores[levelId.name] ?? 0;
    if (CodexCatalog.levelUnlocked(progress, levelId)) {
      return CodexReadingView(
        title: title,
        subtitle: context.l10n.uiLocations,
        paragraphs: [CodexCatalog.levelLore(levelId, context.l10n)],
      );
    }
    return CodexReadingView(
      title: context.l10n.uiEntryLocked,
      subtitle: title,
      paragraphs: [
        context.l10n.codexUnlockLevel(count: target, level: title),
        context.l10n.codexScoreProgress(current: current, target: target),
      ],
    );
  }
}
