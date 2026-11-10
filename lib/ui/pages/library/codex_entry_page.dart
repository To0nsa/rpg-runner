import 'package:game_presentation/enemy_text.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:flutter/material.dart';
import 'package:game_presentation/ability_text.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/levels/level_id.dart';

import '../../codex/codex_catalog.dart';
import '../../components/enemy_portrait.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app/app_state.dart';

import 'package:game_presentation/gear_text.dart';
import 'package:runner_core/abilities/ability_def.dart';

import '../../theme/ui_tokens.dart';
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
      title: unlocked
          ? enemyDisplayName(enemy, strings: context.gameL10n)
          : context.l10n.uiBestiary,
      background: ColoredBox(color: context.ui.colors.background),
      child: SafeArea(
        top: false,
        child: unlocked
            ? CodexReadingView(
                title: enemyDisplayName(enemy, strings: context.gameL10n),
                subtitle: enemy.isBoss
                    ? context.l10n.uiBestiaryBoss
                    : context.l10n.uiBestiary,
                paragraphs: const [],
                children: [
                  _EnemyCombat(enemy: enemy),
                  _ReadingSection(
                    title: context.l10n.uiFieldNotes,
                    text: CodexCatalog.enemyLore(enemy, context.l10n),
                  ),
                  for (final summon in CodexCatalog.summonsFor(enemy))
                    _SummonSection(enemy: summon),
                ],
              )
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

/// Summons are part of the boss discovery, without a second kill gate.
class _SummonSection extends StatelessWidget {
  const _SummonSection({required this.enemy});
  final EnemyId enemy;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: ui.space.lg),
        Divider(color: ui.colors.outline),
        Row(
          children: [
            SizedBox(width: 56, height: 56, child: EnemyPortrait(enemy: enemy)),
            SizedBox(width: ui.space.sm),
            Expanded(
              child: Text(
                enemyDisplayName(enemy, strings: context.gameL10n),
                style: ui.text.title,
              ),
            ),
          ],
        ),
        Text(context.l10n.uiSummonedCreature, style: ui.text.body),
        _EnemyCombat(enemy: enemy),
        _ReadingSection(
          title: context.l10n.uiFieldNotes,
          text: CodexCatalog.enemyLore(enemy, context.l10n),
        ),
      ],
    );
  }
}

class _EnemyCombat extends StatelessWidget {
  const _EnemyCombat({required this.enemy});
  final EnemyId enemy;
  @override
  Widget build(BuildContext context) {
    final archetype = const EnemyCatalog().get(enemy);
    final resistances = <String>[];
    final weaknesses = <String>[];
    for (final type in DamageType.values) {
      final bp = archetype.resistance.modBpFor(type);
      final percentage = bp.abs() / 100;
      if (bp < 0) {
        resistances.add(
          context.l10n.codexResistance(
            type: damageTypeDisplayName(type, strings: context.gameL10n),
            percent: percentage,
          ),
        );
      }
      if (bp > 0) {
        weaknesses.add(
          context.l10n.codexWeakness(
            type: damageTypeDisplayName(type, strings: context.gameL10n),
            percent: percentage,
          ),
        );
      }
    }
    final attacks = CodexCatalog.attacks(enemy)
        .map((ability) {
          final types = [
            for (final type in DamageType.values)
              if (ability.baseDamageType.weightOf(type) > 0)
                ability.baseDamageType is DamageType
                    ? damageTypeDisplayName(type, strings: context.gameL10n)
                    : context.l10n.codexDamageMix(
                        type: damageTypeDisplayName(
                          type,
                          strings: context.gameL10n,
                        ),
                        percent:
                            (100 *
                                    ability.baseDamageType.weightOf(type) /
                                    ability.baseDamageType.totalWeight)
                                .round(),
                      ),
          ];
          return context.l10n.codexAttack(
            ability: abilityDisplayName(ability.id, strings: context.gameL10n),
            category: _categoryName(ability.category, context.l10n),
            types: types.join(' + '),
          );
        })
        .join('\n\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReadingSection(
          title: context.l10n.uiBehaviour,
          text: CodexCatalog.enemyTactics(enemy, context.l10n),
        ),
        _ReadingSection(title: context.l10n.uiAttacks, text: attacks),
        _ReadingSection(
          title: context.l10n.uiResistances,
          text: resistances.isEmpty
              ? context.l10n.uiNoInnateDamageResistances
              : resistances.join('\n'),
        ),
        _ReadingSection(
          title: context.l10n.uiWeaknesses,
          text: weaknesses.isEmpty
              ? context.l10n.uiNoInnateDamageWeaknesses
              : weaknesses.join('\n'),
        ),
      ],
    );
  }
}

class _ReadingSection extends StatelessWidget {
  const _ReadingSection({required this.title, required this.text});
  final String title, text;
  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Padding(
      padding: EdgeInsets.only(top: ui.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ui.text.headline),
          SizedBox(height: ui.space.xs),
          Text(text, style: ui.text.body.copyWith(fontSize: 18, height: 1.45)),
        ],
      ),
    );
  }
}

String _categoryName(AbilityCategory category, AppLocalizations l10n) =>
    switch (category) {
      AbilityCategory.melee => l10n.abilityCategoryMelee,
      AbilityCategory.ranged => l10n.abilityCategoryRanged,
      AbilityCategory.mobility => l10n.abilityCategoryMobility,
      AbilityCategory.defense => l10n.abilityCategoryDefense,
      AbilityCategory.utility => l10n.abilityCategoryUtility,
    };
