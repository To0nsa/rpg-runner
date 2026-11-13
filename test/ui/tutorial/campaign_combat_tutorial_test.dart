import 'package:runner_core/snapshots/camera_snapshot.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_content_pipeline/campaign_tutorial.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/campaign/campaign_registry.dart';
import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/snapshots/combat_opportunity_snapshot.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/game_state_snapshot.dart';
import 'package:runner_core/snapshots/player_hud_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/input/runner_gameplay_action.dart';
import 'package:rpg_runner/ui/tutorial/campaign_tutorial_controller.dart';

void main() {
  CampaignTutorialController create(_Controller c) {
    final tutorial = CampaignTutorialController(
      controller: c,
      mission: campaignMissions['reporting_for_duty'],
      sequences: [
        CampaignCombatTutorial.introduction(
          missionChunkId: 'mission_chunk_10',
          markerSalt: 1,
        ),
      ],
      initialHud: {
        TutorialHudElement.movement,
        TutorialHudElement.jump,
        TutorialHudElement.mobility,
      },
      cancelInput: () {},
    );
    addTearDown(tutorial.dispose);
    tutorial.startNormally();
    return tutorial;
  }

  test('real delivery locks shots; real melee execution unlocks; interrupted presses do neither', () {
    final c = _Controller();
    final t = create(c);
    c.emitTick();
    expect(t.target, CampaignTutorialTarget.enemy);
    expect(t.acceptAction(RunnerGameplayAction.projectile), isFalse);
    t.nextStep();
    expect(t.target, CampaignTutorialTarget.projectile);
    t.suspend();
    expect(t.acceptAction(RunnerGameplayAction.projectile), isFalse);
    t.resumeGuidance();
    expect(t.acceptAction(RunnerGameplayAction.projectile), isTrue);
    c.emitTick();
    expect(t.projectileLocked, isFalse); // rejected/cancelled before execution
    expect(t.allows(RunnerGameplayAction.projectile), isTrue);
    c.attack(AbilitySlot.projectile);
    c.emitTick();
    expect(t.projectileLocked, isTrue);
    expect(t.allows(RunnerGameplayAction.projectile), isFalse);
    expect(t.allows(RunnerGameplayAction.jump), isTrue);
    expect(t.allows(RunnerGameplayAction.moveLeft), isTrue);
    expect(t.isVisible(TutorialHudElement.primary), isFalse);
    c.melee = true;
    c.stationary = false;
    c.emitTick();
    expect(t.showing, isFalse);
    c.stationary = true;
    c.idle = false;
    c.emitTick();
    expect(t.showing, isFalse);
    c.idle = true;
    c.snapshot.hud.canAffordMelee = false;
    c.emitTick();
    expect(t.showing, isFalse);
    c.snapshot.hud.canAffordMelee = true;
    c.emitTick();
    expect(t.target, CampaignTutorialTarget.primary);
    expect(t.acceptAction(RunnerGameplayAction.projectile), isFalse);
    expect(t.acceptAction(RunnerGameplayAction.primary), isTrue);
    c.emitTick();
    expect(t.projectileLocked, isTrue); // sword windup interrupted
    c.attack(AbilitySlot.primary);
    c.emitTick();
    expect(t.projectileLocked, isFalse);
    expect(t.combatPracticeHint, isNull);
    expect(t.allows(RunnerGameplayAction.primary), isTrue);
    expect(t.allows(RunnerGameplayAction.projectile), isTrue);
    c.emitTick();
    expect(t.showing, isFalse);
  });
  for (final deadAfterShot in [false, true]) {
    test('dead target releases guidance, after shot=$deadAfterShot', () {
      final c = _Controller();
      final t = create(c);
      if (deadAfterShot) {
        c.emitTick();
        t.nextStep();
        t.acceptAction(RunnerGameplayAction.projectile);
        c.attack(AbilitySlot.projectile);
      }
      c.dead = true;
      c.emitTick();
      expect(t.showing, isFalse);
      expect(t.projectileLocked, isFalse);
      expect(t.allows(RunnerGameplayAction.primary), isTrue);
      expect(t.allows(RunnerGameplayAction.projectile), isTrue);
    });
  }
  test('enemy body and authored spotlight must be fully inside the camera', () {
    final c = _Controller();
    final t = create(c);
    c.snapshot.camera = const CameraSnapshot(
      centerX: 5400,
      centerY: 135,
      viewWidth: 600,
      viewHeight: 270,
    );
    c.emitTick();
    expect(t.showing, isFalse); // anchor is visible but body is clipped
    c.snapshot.camera = const CameraSnapshot(
      centerX: 5426,
      centerY: 135,
      viewWidth: 600,
      viewHeight: 270,
    );
    c.emitTick();
    expect(t.showing, isFalse); // body fits but the authored opening does not
    c.snapshot.camera = const CameraSnapshot(
      centerX: 5500,
      centerY: 135,
      viewWidth: 600,
      viewHeight: 270,
    );
    c.emitTick();
    expect(t.target, CampaignTutorialTarget.enemy);
    expect(t.worldTargetBounds, isNotNull);
  });
  test('unready projectile waits and alternate build is preserved without tap-only trap', () {
    final c = _Controller();
    final t = create(c);
    c.snapshot.hud.canAffordProjectile = false;
    c.emitTick();
    expect(t.showing, isFalse);
    c.snapshot.hud.canAffordProjectile = true;
    c.idle = false;
    c.emitTick();
    expect(t.showing, isFalse);
    c.idle = true;
    c.reach = false;
    c.emitTick();
    expect(t.showing, isFalse);
    c.reach = true;
    c.snapshot.hud.abilityProjectileId = 'eloise.quick_shot';
    c.emitTick();
    expect(t.showing, isFalse);
    expect(t.allows(RunnerGameplayAction.primary), isTrue);
    expect(c.snapshot.hud.abilityProjectileId, 'eloise.quick_shot');
    t.stop();
    expect(c.events, isEmpty);
    expect(c.listeners, isEmpty);
  });
}

// Policy fixtures; real actor movement and attacks are covered by the host test.
class _Controller extends Fake implements GameController {
  @override
  final _Snapshot snapshot = _Snapshot();
  final listeners = <VoidCallback>[];
  final events = <void Function(GameEvent)>[];
  bool dead = false,
      melee = false,
      idle = true,
      reach = true,
      stationary = true;
  @override
  int get tickHz => 60;
  @override
  CombatOpportunitySnapshot? campaignCombatOpportunity(
    CampaignEnemyTarget target,
  ) => dead
      ? null
      : CombatOpportunitySnapshot(
          entityId: 2,
          targetStationary: stationary,
          x: 5700,
          y: 180,
          playerIdle: idle,
          inMeleeReach: melee,
          inProjectileReach: reach,
        );
  @override
  void addCompletedTickListener(VoidCallback l) => listeners.add(l);
  @override
  void removeCompletedTickListener(VoidCallback l) => listeners.remove(l);
  @override
  void addEventListener(void Function(GameEvent) l) => events.add(l);
  @override
  void removeEventListener(void Function(GameEvent) l) => events.remove(l);
  @override
  void setPaused(bool value) {}
  void emitTick() {
    for (final l in List.of(listeners)) {
      l();
    }
  }

  void attack(AbilitySlot slot) {
    for (final l in List.of(events)) {
      l(PlayerAttackExecutedEvent(tick: 1, slot: slot, abilityId: 'fixture'));
    }
  }
}

class _Snapshot extends Fake implements GameStateSnapshot {
  @override
  CameraSnapshot camera = const CameraSnapshot(
    centerX: 5500,
    centerY: 135,
    viewWidth: 600,
    viewHeight: 270,
  );
  @override
  List<EntityRenderSnapshot> get entities => [
    playerEntity,
    EntityRenderSnapshot(
      id: 2,
      kind: EntityKind.enemy,
      pos: const Vec2(5700, 180),
      size: const Vec2(48, 64),
      facing: Facing.left,
      anim: AnimKey.idle,
      grounded: true,
    ),
  ];
  @override
  final _Hud hud = _Hud();
  @override
  bool get gameOver => false;
  @override
  EntityRenderSnapshot get playerEntity => EntityRenderSnapshot(
    id: 1,
    kind: EntityKind.player,
    pos: const Vec2(5500, 180),
    facing: Facing.right,
    anim: AnimKey.idle,
    grounded: true,
  );
}

class _Hud extends Fake implements PlayerHudSnapshot {
  @override
  String abilityPrimaryId = 'eloise.seeker_slash';
  @override
  String abilityProjectileId = 'eloise.snap_shot';
  @override
  bool meleeSlotValid = true;
  @override
  bool projectileSlotValid = true;
  @override
  bool canAffordMelee = true;
  @override
  bool canAffordProjectile = true;
  @override
  final cooldownTicksLeft = List.filled(8, 0);
}
