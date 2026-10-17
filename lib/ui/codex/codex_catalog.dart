import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/combat/damage_type.dart';
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

  static const openingTitle = 'Before the dark sky';
  static const opening =
      'Éloïse was born in Elingen, in Haute-Lothringen, the only child of '
      'Krenth, a respected lord, and Soturi, a warrior from the East. They '
      'ruled the region through her first ten years. Then they departed on a '
      'mysterious quest and never returned.\n\n'
      'Even as a child, Éloïse showed uncommon strength and magical ability. '
      'After her parents disappeared, Aldebarant, a close friend of Soturi, '
      'guided her training. Later stories claimed it lasted several lifetimes '
      'in other dimensions.\n\n'
      'At thirteen, while orcs from the Ashen mountains pushed the war toward '
      'Basse-Lothringen, her people chose her to lead them. At fifteen, she '
      'commanded Lothringen’s forces and drove the invaders back. The war, '
      'however, had concealed another threat: a demonic cult was corrupting '
      'the primeval forest. Éloïse founded La Main to purge that corruption.\n\n'
      'Now she is seventeen, and the sky over the forest has suddenly '
      'darkened. The danger that grew unseen during the war lies ahead.';

  static String enemyLore(EnemyId id) => switch (id) {
    EnemyId.grojib =>
      'Among the cult’s forces in the forest, Grojib closes the distance '
          'without hesitation. Those who serve the power behind the black sky '
          'need more than hidden rites: they need fighters who can hold the paths '
          'and prevent anyone from reaching their work. Grojib is one of those obstacles.',
    EnemyId.hashash =>
      'Hashash fights from the uncertainty of the forest, appearing where '
          'attention has already moved on. The cult’s purpose is served as much '
          'by an interrupted journey as by a defended gate. In these woods, '
          'an apparently empty path is no promise of safe passage.',
    EnemyId.derf =>
      'Derf is a cultist whose outward form conceals what service to the '
          'darkness has made of them. The transformation witnessed in the forest '
          'turns a distant spellcaster into a pursuing, tentacled threat. '
          'Their body bears the consequence of the corruption they help to spread.',
    EnemyId.unocoDemon =>
      'The Unoco demons encountered over the forest fight alongside the cult’s '
          'forces. Their presence makes the corruption impossible to dismiss as '
          'rumour. They carry the threat above the paths, where walls and broken '
          'ground offer little protection from a spell cast out of the air.',
    EnemyId.bringerOfDeath =>
      'The Bringer of Death bars the way through a clearing claimed by the '
          'darkness. Its scythe and rising pillars leave little room for hesitation. '
          'Defeating this guardian opens a way deeper into the forest; it does '
          'not yet explain who darkened the sky.',
    EnemyId.voidbornGoddess =>
      'The name Voidborn Goddess records the terror of the encounter, not '
          'proof of divinity. Beyond the cult’s first defences, this presence '
          'turns the clearing itself into a threat. Éloïse can learn how it '
          'fights without yet knowing what brought it into the forest.',
    EnemyId.shoggoth =>
      'Shoggoth is encountered among the deeper horrors guarding the route. '
          'Smaller creatures accompany its assaults, making the fight feel '
          'less like a duel than a struggle to keep a patch of ground. Its '
          'arrival belongs to the spreading corruption; its distant origin '
          'remains unrecorded.',
    EnemyId.voidcaller =>
      'The Voidcaller’s presence is marked by beams, erupting claws and '
          'summoned tentacles. It stands among the powers opposing Éloïse’s '
          'advance through the corrupted forest. The title describes what '
          'she witnesses, while the nature of what answers its call remains uncertain.',
    EnemyId.shoggothMinion =>
      'These smaller creatures enter the fight at Shoggoth’s summons. '
          'They are part of the same immediate threat, pressing an opponent '
          'while the larger creature prepares its next assault. Their appearance '
          'is a warning that the ground around Shoggoth will not stay clear.',
    EnemyId.voidTentacle =>
      'A tentacle called into the arena is a local expression of the '
          'Voidcaller’s reach. It makes dangerous ground out of a place that '
          'was open a moment before. Destroying it removes that threat, '
          'but leaves the power calling it forth to be confronted.',
  };

  static String enemyTactics(EnemyId id) => switch (id) {
    EnemyId.grojib => 'A ground pursuer with a follow-up melee strike that can stun on hit. Leave room for the second swing.',
    EnemyId.hashash => 'A mobile assassin with a teleporting ambush. Watch for its return before committing.',
    EnemyId.derf => 'Transforms from a caster into a melee pursuer. Its extended tentacle gives the strike unusual reach.',
    EnemyId.unocoDemon => 'A flying caster that can also strike at close range. Keep moving while its projectile is aimed.',
    EnemyId.bringerOfDeath => 'A scythe fighter with dark pillars. Read the wind-up and move clear of the marked ground.',
    EnemyId.voidbornGoddess => 'Combines claw attacks, dark orbs and ground eruptions. Reposition when the arena is threatened.',
    EnemyId.shoggoth => 'Uses tentacles, dark orbs and summoned creatures. Manage the smaller threats while watching the boss.',
    EnemyId.voidcaller => 'Uses vertical and diagonal beams, fire claws and tentacle summons. Keep a route out of overlapping attacks.',
    EnemyId.shoggothMinion => 'A small ground attacker summoned by Shoggoth. Avoid being crowded while the boss attacks.',
    EnemyId.voidTentacle => 'A summoned melee threat. Move beyond its lash before turning to attack it.',
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

  static String damageName(DamageType type) =>
      '${type.name[0].toUpperCase()}${type.name.substring(1)}';

  static String levelName(LevelId id) => switch (id) {
    LevelId.forest || LevelId.field => id.displayName,
    _ => throw ArgumentError.value(id, 'id', 'No published Codex entry'),
  };

  static String levelLore(LevelId id) => switch (id) {
    LevelId.forest =>
      'Val Outpost stands beside the road through the Long-Eared Owls’ Forest. '
          'Its soldiers patrol the wooded route, train for the forest’s '
          'hazards, and carry warnings of danger back to Théodonis. Travelers '
          'can rest under their guard before continuing their journey.',
    LevelId.field =>
      'Léonards’ farm is the largest agricultural estate around Théodonis. '
          'A powerful family oversees its fields and harvests.',
    _ => throw ArgumentError.value(id, 'id', 'No published Codex entry'),
  };
}
