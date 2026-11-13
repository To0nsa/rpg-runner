import 'package:flutter/material.dart';
import 'package:game_presentation/ability_text.dart';
import 'package:game_presentation/enemy_text.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:game_presentation/gear_text.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';

import '../../codex/codex_catalog.dart';
import '../../components/enemy_portrait.dart';
import '../../l10n/app_localization.dart';
import '../../theme/ui_bestiary_theme.dart';
import '../../theme/ui_tokens.dart';

/// Read-only, static field guide. The entry route owns discovery checks and must
/// only mount this view after the parent enemy has been unlocked.
class BestiaryEntryView extends StatelessWidget {
  const BestiaryEntryView({super.key, required this.enemy});

  final EnemyId enemy;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final theme = context.bestiary;
    return SingleChildScrollView(
      key: PageStorageKey<EnemyId>(enemy),
      padding: EdgeInsets.all(ui.space.xs),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.background,
              border: Border.all(color: theme.outline),
              borderRadius: BorderRadius.circular(ui.radii.md),
            ),
            child: Padding(
              padding: EdgeInsets.all(ui.space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CreatureDetails(enemy: enemy),
                  for (final summon in CodexCatalog.summonsFor(enemy)) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: ui.space.sm),
                      child: Divider(height: 1, color: theme.outline),
                    ),
                    _CreatureDetails(enemy: summon),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatureDetails extends StatelessWidget {
  const _CreatureDetails({required this.enemy});

  final EnemyId enemy;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final theme = context.bestiary;
    final attacks = _Attacks(enemy: enemy);
    final behaviourAndDefences = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: context.l10n.uiBehaviour,
          child: Text(
            CodexCatalog.enemyTactics(enemy, context.l10n),
            style: theme.body,
          ),
        ),
        SizedBox(height: ui.space.sm),
        _Defences(enemy: enemy),
      ],
    );
    return Column(
      key: ValueKey('bestiary-creature-${enemy.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CreatureHeader(enemy: enemy),
        SizedBox(height: ui.space.sm),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.surface,
            border: BorderDirectional(
              start: BorderSide(color: theme.accent, width: 2),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(ui.space.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.codexCombatAdvice,
                  style: theme.detail.copyWith(
                    color: theme.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: ui.space.xxs),
                Text(
                  CodexCatalog.enemyAdvice(enemy, context.l10n),
                  style: theme.body,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: ui.space.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final textWidth = MediaQuery.textScalerOf(context)
                .scale(theme.body.fontSize!);
            if (constraints.maxWidth >=
                480 * textWidth / theme.body.fontSize!) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: attacks),
                  SizedBox(width: ui.space.md),
                  Expanded(child: behaviourAndDefences),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                attacks,
                SizedBox(height: ui.space.sm),
                behaviourAndDefences,
              ],
            );
          },
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: ui.space.sm),
          child: Divider(height: 1, color: theme.outline),
        ),
        _Section(
          title: context.l10n.uiFieldNotes,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              CodexCatalog.enemyLore(enemy, context.l10n),
              style: theme.lore,
            ),
          ),
        ),
      ],
    );
  }
}

class _CreatureHeader extends StatelessWidget {
  const _CreatureHeader({required this.enemy});

  final EnemyId enemy;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final theme = context.bestiary;
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (enemy.isBoss || enemy.isBossSummon) ...[
          Text(
            enemy.isBoss
                ? context.l10n.codexBoss
                : context.l10n.uiSummonedCreature,
            style: theme.detail.copyWith(color: theme.accent),
          ),
          SizedBox(height: ui.space.xxs),
        ],
        Semantics(
          header: true,
          child: Text(
            enemyDisplayName(enemy, strings: context.gameL10n),
            style: enemy.isBossSummon
                ? theme.title.copyWith(fontSize: ui.text.headline.fontSize)
                : theme.title,
          ),
        ),
        SizedBox(height: ui.space.xxs),
        Text(CodexCatalog.enemyRole(enemy, context.l10n), style: theme.detail),
      ],
    );
    final portrait = SizedBox(
      width: enemy.isBossSummon ? 64 : 80,
      height: enemy.isBossSummon ? 64 : 80,
      child: EnemyPortrait(enemy: enemy),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidth = MediaQuery.textScalerOf(context)
            .scale(theme.title.fontSize!);
        if (constraints.maxWidth >= 280 * textWidth / theme.title.fontSize!) {
          return Row(
            children: [
              Expanded(child: identity),
              SizedBox(width: ui.space.sm),
              portrait,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            identity,
            SizedBox(height: ui.space.xs),
            Center(child: portrait),
          ],
        );
      },
    );
  }
}

class _Attacks extends StatelessWidget {
  const _Attacks({required this.enemy});

  final EnemyId enemy;

  @override
  Widget build(BuildContext context) => _Section(
    title: context.l10n.uiAttacks,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final ability in CodexCatalog.attacks(enemy))
          _AttackRow(ability: ability),
      ],
    ),
  );
}

class _AttackRow extends StatelessWidget {
  const _AttackRow({required this.ability});

  final AbilityDef ability;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final theme = context.bestiary;
    final types = [
      for (final type in DamageType.values)
        if (ability.baseDamageType.weightOf(type) > 0)
          ability.baseDamageType is DamageType
              ? damageTypeDisplayName(type, strings: context.gameL10n)
              : context.l10n.codexDamageMix(
                  type: damageTypeDisplayName(type, strings: context.gameL10n),
                  percent:
                      (100 *
                              ability.baseDamageType.weightOf(type) /
                              ability.baseDamageType.totalWeight)
                          .round(),
                ),
    ];
    return MergeSemantics(
      child: Container(
        key: ValueKey('bestiary-attack-${ability.id}'),
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: ui.space.xxs),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.outline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              abilityDisplayName(ability.id, strings: context.gameL10n),
              style: theme.heading,
            ),
            SizedBox(height: ui.space.xxs),
            Text(
              context.l10n.codexAttackDetails(
                category: _categoryName(ability.category, context.l10n),
                types: types.join(' + '),
              ),
              style: theme.detail,
            ),
          ],
        ),
      ),
    );
  }
}

class _Defences extends StatelessWidget {
  const _Defences({required this.enemy});

  final EnemyId enemy;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final theme = context.bestiary;
    final archetype = const EnemyCatalog().get(enemy);
    final resistances = <String>[];
    final weaknesses = <String>[];
    for (final type in DamageType.values) {
      final bp = archetype.resistance.modBpFor(type);
      final name = damageTypeDisplayName(type, strings: context.gameL10n);
      if (bp < 0) {
        resistances.add(
          context.l10n.codexResistance(type: name, percent: bp.abs() / 100),
        );
      } else if (bp > 0) {
        weaknesses.add(
          context.l10n.codexWeakness(type: name, percent: bp / 100),
        );
      }
    }
    Widget group(String title, List<String> values) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.detail.copyWith(
            color: theme.heading.color,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: ui.space.xxs),
        if (values.isEmpty)
          Text(context.l10n.codexNoInnateModifiers, style: theme.detail)
        else
          for (final value in values) Text(value, style: theme.body),
      ],
    );
    return _Section(
      title: context.l10n.codexInnateDefences,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          group(context.l10n.uiResistances, resistances),
          SizedBox(height: ui.space.sm),
          group(context.l10n.uiWeaknesses, weaknesses),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(title, style: context.bestiary.heading),
      ),
      SizedBox(height: context.ui.space.xs),
      child,
    ],
  );
}

String _categoryName(AbilityCategory category, AppLocalizations l10n) =>
    switch (category) {
      AbilityCategory.melee => l10n.abilityCategoryMelee,
      AbilityCategory.ranged => l10n.abilityCategoryRanged,
      AbilityCategory.mobility => l10n.abilityCategoryMobility,
      AbilityCategory.defense => l10n.abilityCategoryDefense,
      AbilityCategory.utility => l10n.abilityCategoryUtility,
    };
