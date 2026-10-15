import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/levels/level_id.dart';

import '../state/ownership/codex_progress.dart';

/// Presentation and discovery policy; combat values stay in Core's catalogs.
abstract final class CodexCatalog {
  static const regularEnemyKills = 10;
  static const bossKills = 5;

  /// Best score in a single validated Competitive run, separately per level.
  static const levelScoreRequirements = <LevelId, int>{
    LevelId.forest: 10000,
    LevelId.field: 10000,
  };

  static int killsRequired(EnemyId id) =>
      id.isBoss ? bossKills : regularEnemyKills;
  static bool enemyUnlocked(CodexProgress progress, EnemyId id) =>
      (progress.enemyKills[id.name] ?? 0) >= killsRequired(id);
  static bool levelUnlocked(CodexProgress progress, LevelId id) =>
      levelScoreRequirements.containsKey(id) &&
      (progress.competitiveBestScores[id.name] ?? 0) >=
          levelScoreRequirements[id]!;

  static const openingTitle = 'When the sky darkened';
  static const opening =
      'Éloïse is seventeen when the sky suddenly darkens above the forest. '
      'The war against the orcs has already concealed another threat: a cult '
      'working to corrupt the ancient woodland. Its followers now stand '
      'between her and whoever is responsible for the black sky.\n\n'
      'She enters the forest. These pages gather what can be learned along '
      'the way: the enemies she faces, the places she crosses, and the cost '
      'of reaching further into the darkness.';

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
    EnemyId.grojib => 'A ground pursuer with a follow-up melee strike. Leave room for the second swing.',
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
    LevelId.forest => 'Forest',
    LevelId.field => 'Field',
    _ => throw ArgumentError.value(id, 'id', 'No published Codex entry'),
  };

  static String levelLore(LevelId id) => switch (id) {
    LevelId.forest =>
      'The ancient forest is the heart of the present crisis. While the '
          'region fought the orcs, a demonic cult used the conflict to conceal '
          'its corruption of the woodland. Now the sky above it has gone black.\n\n'
          'Éloïse enters a place whose paths are held by followers of that '
          'hidden power. Each clearing offers a little more knowledge of the '
          'threat, and demands another confrontation before she can continue. '
          'The forest’s older history reaches back to the Dames de la forêt '
          'and the fair folk, long before humanoid settlement.',
    LevelId.field =>
      'Open land is part of what Lothringen must struggle to preserve. '
          'Beyond its settlements, a journey depends on exposed routes and '
          'the ability to keep moving when safety falls behind.\n\n'
          'The Field presents that pressure in open terrain. Distance provides '
          'time to read what lies ahead, but reaching further still requires '
          'care with resources, obstacles and enemies. In Éloïse’s time, '
          'the region’s struggle with the cult is still unfolding.',
    _ => throw ArgumentError.value(id, 'id', 'No published Codex entry'),
  };
}
