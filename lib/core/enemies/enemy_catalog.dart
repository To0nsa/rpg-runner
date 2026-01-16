import '../ecs/stores/body_store.dart';
import '../ecs/stores/collider_aabb_store.dart';
import '../ecs/stores/combat/creature_tag_store.dart';
import '../ecs/stores/combat/damage_resistance_store.dart';
import '../ecs/stores/combat/status_immunity_store.dart';
import '../ecs/stores/health_store.dart';
import '../ecs/stores/mana_store.dart';
import '../ecs/stores/stamina_store.dart';
import '../combat/creature_tag.dart';
import '../anim/anim_resolver.dart';
import '../contracts/render_anim_set_definition.dart';
import '../spells/spell_id.dart';
import '../snapshots/enums.dart';
import 'enemy_id.dart';

// -----------------------------------------------------------------------------
// Unoco Demon render animation strip definitions (authoring-time)
// -----------------------------------------------------------------------------

const int _unocoAnimFrameWidth = 81;
const int _unocoAnimFrameHeight = 71;

const int _unocoAnimIdleFrames = 4;
const double _unocoAnimIdleStepSeconds = 0.12;

const int _unocoAnimMoveFrames = 4;
const double _unocoAnimMoveStepSeconds = 0.12;

const int _unocoAnimHitFrames = 4;
const double _unocoAnimHitStepSeconds = 0.10;

const int _unocoAnimDeathFrames = 7;
const double _unocoAnimDeathStepSeconds = 0.12;

const double _unocoHitAnimSeconds =
    _unocoAnimHitFrames * _unocoAnimHitStepSeconds;

const Map<AnimKey, int> _unocoAnimFrameCountsByKey = <AnimKey, int>{
  AnimKey.idle: _unocoAnimIdleFrames,
  AnimKey.run: _unocoAnimMoveFrames,
  AnimKey.hit: _unocoAnimHitFrames,
  AnimKey.death: _unocoAnimDeathFrames,
};

const Map<AnimKey, double> _unocoAnimStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.idle: _unocoAnimIdleStepSeconds,
  AnimKey.run: _unocoAnimMoveStepSeconds,
  AnimKey.hit: _unocoAnimHitStepSeconds,
  AnimKey.death: _unocoAnimDeathStepSeconds,
};

const Map<AnimKey, String> _unocoAnimSourcesByKey = <AnimKey, String>{
  AnimKey.idle: 'entities/enemies/unoco/flying.png',
  AnimKey.run: 'entities/enemies/unoco/flying.png',
  AnimKey.hit: 'entities/enemies/unoco/hit.png',
  AnimKey.death: 'entities/enemies/unoco/death.png',
};

const RenderAnimSetDefinition _unocoRenderAnim = RenderAnimSetDefinition(
  frameWidth: _unocoAnimFrameWidth,
  frameHeight: _unocoAnimFrameHeight,
  sourcesByKey: _unocoAnimSourcesByKey,
  frameCountsByKey: _unocoAnimFrameCountsByKey,
  stepTimeSecondsByKey: _unocoAnimStepTimeSecondsByKey,
);

const AnimProfile _unocoAnimProfile = AnimProfile(
  minMoveSpeed: 1.0,
  runSpeedThresholdX: 0.0,
  supportsWalk: false,
  supportsJumpFall: false,
  attackAnimKey: AnimKey.idle,
);

// -----------------------------------------------------------------------------
// Werewolf (ground enemy) render animation strip definitions (authoring-time)
// -----------------------------------------------------------------------------

const int _werewolfAnimFrameWidth = 100;
const int _werewolfAnimFrameHeight = 64;

const int _werewolfAnimIdleFrames = 4;
const double _werewolfAnimIdleStepSeconds = 0.14;

const int _werewolfAnimMoveFrames = 7;
const double _werewolfAnimMoveStepSeconds = 0.08;

const int _werewolfAnimWalkFrames = _werewolfAnimMoveFrames;
const double _werewolfAnimWalkStepSeconds = _werewolfAnimMoveStepSeconds;

const int _werewolfAnimHitFrames = 4;
const double _werewolfAnimHitStepSeconds = 0.10;

const int _werewolfAnimDeathFrames = 6;
const double _werewolfAnimDeathStepSeconds = 0.12;

const int _werewolfAnimAttackFrames = 6;
const double _werewolfAnimAttackStepSeconds = 0.06;

const int _werewolfAnimJumpFrames = 6;
const double _werewolfAnimJumpStepSeconds = 0.10;

const int _werewolfAnimFallFrames = 3;
const double _werewolfAnimFallStepSeconds = 0.10;
const double _werewolfHitAnimSeconds =
    _werewolfAnimHitFrames * _werewolfAnimHitStepSeconds;

const Map<AnimKey, int> _werewolfAnimFrameCountsByKey = <AnimKey, int>{
  AnimKey.idle: _werewolfAnimIdleFrames,
  AnimKey.run: _werewolfAnimMoveFrames,
  AnimKey.walk: _werewolfAnimWalkFrames,
  AnimKey.attack: _werewolfAnimAttackFrames,
  AnimKey.hit: _werewolfAnimHitFrames,
  AnimKey.death: _werewolfAnimDeathFrames,
  AnimKey.jump: _werewolfAnimJumpFrames,
  AnimKey.fall: _werewolfAnimFallFrames,
};

const Map<AnimKey, double> _werewolfAnimStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.idle: _werewolfAnimIdleStepSeconds,
  AnimKey.run: _werewolfAnimMoveStepSeconds,
  AnimKey.walk: _werewolfAnimWalkStepSeconds,
  AnimKey.attack: _werewolfAnimAttackStepSeconds,
  AnimKey.hit: _werewolfAnimHitStepSeconds,
  AnimKey.death: _werewolfAnimDeathStepSeconds,
  AnimKey.jump: _werewolfAnimJumpStepSeconds,
  AnimKey.fall: _werewolfAnimFallStepSeconds,
};

const Map<AnimKey, String> _werewolfAnimSourcesByKey = <AnimKey, String>{
  AnimKey.idle: 'entities/enemies/werewolf/idle.png',
  AnimKey.run: 'entities/enemies/werewolf/run.png',
  AnimKey.walk: 'entities/enemies/werewolf/walk.png',
  AnimKey.attack: 'entities/enemies/werewolf/attack.png',
  AnimKey.hit: 'entities/enemies/werewolf/hit.png',
  AnimKey.death: 'entities/enemies/werewolf/death.png',
  AnimKey.jump: 'entities/enemies/werewolf/jump.png',
  AnimKey.fall: 'entities/enemies/werewolf/fall.png',
};

const RenderAnimSetDefinition _werewolfRenderAnim = RenderAnimSetDefinition(
  frameWidth: _werewolfAnimFrameWidth,
  frameHeight: _werewolfAnimFrameHeight,
  sourcesByKey: _werewolfAnimSourcesByKey,
  frameCountsByKey: _werewolfAnimFrameCountsByKey,
  stepTimeSecondsByKey: _werewolfAnimStepTimeSecondsByKey,
);

const AnimProfile _werewolfAnimProfile = AnimProfile(
  minMoveSpeed: 1.0,
  runSpeedThresholdX: 120.0,
);

/// Defines the base stats and physics properties for an enemy type.
///
/// This data is "static" (read-only) configuration used to initialize
/// the ECS components effectively when an enemy spawns.
class EnemyArchetype {
  const EnemyArchetype({
    required this.body,
    required this.collider,
    required this.health,
    required this.mana,
    required this.stamina,
    required this.renderAnim,
    required this.animProfile,
    required this.hitAnimSeconds,
    this.primarySpellId,
    this.artFacingDir = Facing.right,
    this.tags = const CreatureTagDef(),
    this.resistance = const DamageResistanceDef(),
    this.statusImmunity = const StatusImmunityDef(),
  });

  /// Physics configuration (Gravity, Constraints, Kinematics).
  final BodyDef body;

  /// Hitbox size (Collision).
  final ColliderAabbDef collider;

  /// Vitals (HP, Mana, Stamina) configuration.
  final HealthDef health;
  final ManaDef mana;
  final StaminaDef stamina;

  /// Render-only animation metadata (strip paths, frame size, timing).
  final RenderAnimSetDefinition renderAnim;

  /// Core animation profile (movement thresholds and supported keys).
  final AnimProfile animProfile;

  /// Duration the hit animation should be visible (seconds).
  final double hitAnimSeconds;

  /// Optional primary ranged attack spell for this enemy.
  ///
  /// When present, the [EnemySystem] will use this to write cast intents.
  final SpellId? primarySpellId;

  /// Direction the authored art faces when not mirrored.
  ///
  /// Most sprites face right by default, but some packs are authored facing
  /// left. The renderer uses this to mirror correctly based on logical [Facing].
  final Facing artFacingDir;

  /// Broad tags used by combat rules and content filters.
  final CreatureTagDef tags;

  /// Resistance/vulnerability modifiers by damage type.
  final DamageResistanceDef resistance;

  /// Status effect immunities for this enemy.
  final StatusImmunityDef statusImmunity;
}

/// Central registry for Enemy Definitions.
///
/// **Usage**:
/// - Accessed by `EnemySpawnSystem` (or similar) to hydration entities.
/// - Decouples "What an enemy is" from "How to spawn it".
class EnemyCatalog {
  const EnemyCatalog();

  /// Returns the static archetype definition for a given [EnemyId].
  ///
  /// Note: The returned objects are `const` and allocation-light.
  EnemyArchetype get(EnemyId id) {
    switch (id) {
      case EnemyId.unocoDemon:
        return const EnemyArchetype(
          body: BodyDef(
            isKinematic: false,
            useGravity: false,
            gravityScale: 0.0,
            sideMask: BodyDef.sideNone,
            maxVelX: 800.0,
            maxVelY: 800.0,
          ),
          collider: ColliderAabbDef(halfX: 12.0, halfY: 12.0),
          health: HealthDef(hp: 20.0, hpMax: 20.0, regenPerSecond: 0.5),
          mana: ManaDef(mana: 80.0, manaMax: 80.0, regenPerSecond: 5.0),
          stamina: StaminaDef(
            stamina: 0.0,
            staminaMax: 0.0,
            regenPerSecond: 0.0,
          ),
          renderAnim: _unocoRenderAnim,
          animProfile: _unocoAnimProfile,
          hitAnimSeconds: _unocoHitAnimSeconds,
          primarySpellId: SpellId.lightning,
          artFacingDir: Facing.left,
          tags: CreatureTagDef(
            mask: CreatureTagMask.flying | CreatureTagMask.demon,
          ),
          resistance: DamageResistanceDef(fire: -0.5, ice: 0.5),
        );

      case EnemyId.groundEnemy:
        return const EnemyArchetype(
          body: BodyDef(
            isKinematic: false,
            useGravity: true,
            ignoreCeilings: true,
            gravityScale: 1.0,
            sideMask: BodyDef.sideLeft | BodyDef.sideRight,
          ),
          collider: ColliderAabbDef(halfX: 12.0, halfY: 12.0),
          health: HealthDef(hp: 20.0, hpMax: 20.0, regenPerSecond: 0.5),
          mana: ManaDef(mana: 0.0, manaMax: 0.0, regenPerSecond: 0.0),
          stamina: StaminaDef(
            stamina: 0.0,
            staminaMax: 0.0,
            regenPerSecond: 0.0,
          ),
          renderAnim: _werewolfRenderAnim,
          animProfile: _werewolfAnimProfile,
          hitAnimSeconds: _werewolfHitAnimSeconds,
          tags: CreatureTagDef(mask: CreatureTagMask.humanoid),
        );
    }
  }
}
