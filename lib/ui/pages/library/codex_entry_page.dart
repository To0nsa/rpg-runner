import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/levels/level_id.dart';

import '../../codex/codex_catalog.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app/app_state.dart';
import '../../text/ability_text.dart';
import '../../theme/ui_tokens.dart';
import 'codex_widgets.dart';
import 'enemy_portrait.dart';

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
    final progress = context.watch<AppState>().progression;
    final enemy = enemyId == null
        ? null
        : CodexCatalog.parentBoss(enemyId!) ?? enemyId;
    final title = enemy?.displayName ?? CodexCatalog.levelName(levelId!);
    final unlocked = enemy != null
        ? CodexCatalog.enemyUnlocked(progress.enemyDefeats, enemy)
        : CodexCatalog.levelUnlocked(progress.codex, levelId!);
    final current = enemy != null
        ? progress.enemyDefeats.byEnemy[enemy.name] ?? 0
        : progress.codex.competitiveBestScores[levelId!.name] ?? 0;
    final target = enemy != null
        ? CodexCatalog.killsRequired(enemy)
        : CodexCatalog.levelScoreRequirements[levelId]!;
    return MenuScaffold(
      title: unlocked || enemy == null ? title : 'Bestiary',
      background: ColoredBox(color: context.ui.colors.background),
      child: SafeArea(
        top: false,
        child: unlocked
            ? CodexReadingView(
                title: title,
                subtitle: enemy != null
                    ? (enemy.isBoss ? 'Bestiary • Boss' : 'Bestiary')
                    : 'Locations',
                paragraphs: enemy != null
                    ? []
                    : [CodexCatalog.levelLore(levelId!)],
                children: enemy == null
                    ? []
                    : [
                        _EnemyCombat(enemy: enemy),
                        _ReadingSection(
                          title: 'Field notes',
                          text: CodexCatalog.enemyLore(enemy),
                        ),
                        for (final summon in CodexCatalog.summonsFor(enemy))
                          _SummonSection(enemy: summon),
                      ],
              )
            : CodexReadingView(
                title: 'Entry locked',
                subtitle: enemy == null ? title : 'Bestiary',
                paragraphs: [
                  enemy != null
                      ? 'Defeat ${codexNumber(target)} to reveal its attacks, resistances and field notes.'
                      : 'Reach ${codexNumber(target)} points in one Competitive run on $title to reveal its history.',
                  '${codexNumber(current)} / ${codexNumber(target)} ${enemy != null ? 'defeated' : 'best Competitive score'}.',
                ],
              ),
      ),
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
            Expanded(child: Text(enemy.displayName, style: ui.text.title)),
          ],
        ),
        Text('Summoned creature', style: ui.text.body),
        _EnemyCombat(enemy: enemy),
        _ReadingSection(
          title: 'Field notes',
          text: CodexCatalog.enemyLore(enemy),
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
      final percentage = (bp.abs() / 100).toStringAsFixed(
        bp.abs() % 100 == 0 ? 0 : 1,
      );
      if (bp < 0) {
        resistances.add(
          '${CodexCatalog.damageName(type)}: $percentage% less damage',
        );
      }
      if (bp > 0) {
        weaknesses.add(
          '${CodexCatalog.damageName(type)}: $percentage% more damage',
        );
      }
    }
    final attacks = CodexCatalog.attacks(enemy)
        .map((ability) {
          final types = [
            for (final type in DamageType.values)
              if (ability.baseDamageType.weightOf(type) > 0)
                '${CodexCatalog.damageName(type)}${ability.baseDamageType is DamageType ? '' : ' ${(100 * ability.baseDamageType.weightOf(type) / ability.baseDamageType.totalWeight).round()}%'}',
          ];
          return '${abilityDisplayName(ability.id)} • ${ability.category.name}\n${types.join(' + ')} damage';
        })
        .join('\n\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReadingSection(
          title: 'Behaviour',
          text: CodexCatalog.enemyTactics(enemy),
        ),
        _ReadingSection(title: 'Attacks', text: attacks),
        _ReadingSection(
          title: 'Resistances',
          text: resistances.isEmpty
              ? 'No innate damage resistances.'
              : resistances.join('\n'),
        ),
        _ReadingSection(
          title: 'Weaknesses',
          text: weaknesses.isEmpty
              ? 'No innate damage weaknesses.'
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
