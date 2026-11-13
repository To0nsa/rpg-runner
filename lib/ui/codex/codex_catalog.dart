import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/levels/level_id.dart';

import '../levels/level_id_ui.dart';
import '../state/ownership/codex_progress.dart';
import '../state/ownership/enemy_defeats.dart';

/// Presentation and discovery policy; combat values stay in Core's catalogs.
abstract final class CodexCatalog {
  static const regularEnemyKills = 10;
  static const bossKills = 5;

  static Iterable<EnemyId> get bestiaryEntries =>
      EnemyId.values.where((id) => !id.isBossSummon);

  static EnemyId? parentBoss(EnemyId id) => switch (id) {
    EnemyId.shoggothMinion => EnemyId.shoggoth,
    EnemyId.voidTentacle => EnemyId.voidcaller,
    _ => null,
  };

  static Iterable<EnemyId> summonsFor(EnemyId boss) =>
      EnemyId.values.where((id) => parentBoss(id) == boss);

  /// Best score in a single validated Competitive run, separately per level.
  static const levelScoreRequirements = <LevelId, int>{
    LevelId.forest: 10000,
    LevelId.field: 10000,
  };

  static int killsRequired(EnemyId id) =>
      (parentBoss(id) ?? id).isBoss ? bossKills : regularEnemyKills;
  static bool enemyUnlocked(EnemyDefeats defeats, EnemyId id) =>
      (defeats.byEnemy[(parentBoss(id) ?? id).name] ?? 0) >= killsRequired(id);
  static bool levelUnlocked(CodexProgress progress, LevelId id) =>
      levelScoreRequirements.containsKey(id) &&
      (progress.competitiveBestScores[id.name] ?? 0) >=
          levelScoreRequirements[id]!;

  static String enemyLore(EnemyId id, AppLocalizations l10n) => switch (id) {
    EnemyId.grojib => l10n.codexGrojibLore,
    EnemyId.hashash => l10n.codexHashashLore,
    EnemyId.derf => l10n.codexDerfLore,
    EnemyId.unocoDemon => l10n.codexUnocoLore,
    EnemyId.bringerOfDeath => l10n.codexBringerLore,
    EnemyId.voidbornGoddess => l10n.codexGoddessLore,
    EnemyId.shoggoth => l10n.codexShoggothLore,
    EnemyId.voidcaller => l10n.codexVoidcallerLore,
    EnemyId.shoggothMinion => l10n.codexShoggothMinionLore,
    EnemyId.voidTentacle => l10n.codexVoidTentacleLore,
  };

  static String enemyTactics(EnemyId id, AppLocalizations l10n) => switch (id) {
    EnemyId.grojib => l10n.codexGrojibTactics,
    EnemyId.hashash => l10n.codexHashashTactics,
    EnemyId.derf => l10n.codexDerfTactics,
    EnemyId.unocoDemon => l10n.codexUnocoTactics,
    EnemyId.bringerOfDeath => l10n.codexBringerTactics,
    EnemyId.voidbornGoddess => l10n.codexGoddessTactics,
    EnemyId.shoggoth => l10n.codexShoggothTactics,
    EnemyId.voidcaller => l10n.codexVoidcallerTactics,
    EnemyId.shoggothMinion => l10n.codexShoggothMinionTactics,
    EnemyId.voidTentacle => l10n.codexVoidTentacleTactics,
  };

  static String enemyRole(EnemyId id, AppLocalizations l10n) => switch (id) {
    EnemyId.grojib => l10n.codexGrojibRole,
    EnemyId.hashash => l10n.codexHashashRole,
    EnemyId.derf => l10n.codexDerfRole,
    EnemyId.unocoDemon => l10n.codexUnocoRole,
    EnemyId.bringerOfDeath => l10n.codexBringerRole,
    EnemyId.voidbornGoddess => l10n.codexGoddessRole,
    EnemyId.shoggoth => l10n.codexShoggothRole,
    EnemyId.voidcaller => l10n.codexVoidcallerRole,
    EnemyId.shoggothMinion => l10n.codexShoggothMinionRole,
    EnemyId.voidTentacle => l10n.codexVoidTentacleRole,
  };

  static String enemyAdvice(EnemyId id, AppLocalizations l10n) => switch (id) {
    EnemyId.grojib => l10n.codexGrojibAdvice,
    EnemyId.hashash => l10n.codexHashashAdvice,
    EnemyId.derf => l10n.codexDerfAdvice,
    EnemyId.unocoDemon => l10n.codexUnocoAdvice,
    EnemyId.bringerOfDeath => l10n.codexBringerAdvice,
    EnemyId.voidbornGoddess => l10n.codexGoddessAdvice,
    EnemyId.shoggoth => l10n.codexShoggothAdvice,
    EnemyId.voidcaller => l10n.codexVoidcallerAdvice,
    EnemyId.shoggothMinion => l10n.codexShoggothMinionAdvice,
    EnemyId.voidTentacle => l10n.codexVoidTentacleAdvice,
  };

  /// Includes secondary boss attacks, not just the archetype's primary attack.
  static Iterable<AbilityDef> attacks(EnemyId id) {
    final archetype = const EnemyCatalog().get(id);
    final primary =
        archetype.primaryMeleeAbilityId ?? archetype.primaryCastAbilityId!;
    final prefix = '${primary.split('.').first}.';
    return AbilityCatalog.abilities.values.where(
      (ability) => ability.id.startsWith(prefix) && ability.baseDamage > 0,
    );
  }

  static String levelName(LevelId id, AppLocalizations l10n) => switch (id) {
    LevelId.forest || LevelId.field => id.localizedName(l10n),
    _ => throw ArgumentError.value(id, 'id', 'No published Codex entry'),
  };

  static String levelLore(LevelId id, AppLocalizations l10n) => switch (id) {
    LevelId.forest => l10n.codexForestLore,
    LevelId.field => l10n.codexFieldLore,
    _ => throw ArgumentError.value(id, 'id', 'No published Codex entry'),
  };
}
