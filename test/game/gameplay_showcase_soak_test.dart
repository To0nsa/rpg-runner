import 'package:flutter_test/flutter_test.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/game_state_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/input/runner_gameplay_action.dart';
import 'package:rpg_runner/game/input/runner_input_router.dart';
import 'package:rpg_runner/game/input/runner_semantic_action_dispatcher.dart';
import 'package:rpg_runner/game/replay/replay_command_codec.dart';

void main() {
  for (final levelId in LevelRegistry.compiledLevelIds) {
    for (final character in PlayerCharacterRegistry.all) {
      for (final seed in [7, 42, 2026]) {
        test(
          'mixed-input run and replay ${levelId.name}/${character.id.name}/$seed',
          () async {
            GameCore createCore() => GameCore(
              runId: 1,
              seed: seed,
              levelDefinition: LevelRegistry.byId(levelId),
              playerCharacter: character,
            );
            final controller = GameController(core: createCore());
            addTearDown(() {
              controller.shutdown();
              controller.dispose();
            });
            final router = RunnerInputRouter(controller: controller);
            final actions = RunnerSemanticActionDispatcher(
              input: router,
              resolveInputMode: (action) =>
                  _inputMode(controller.snapshot, action),
            );
            final frames = <ReplayCommandFrameV1>[];
            final events = <GameEvent>[];
            final checkpoints = <int, List<Object?>>{};
            controller.addAppliedCommandFrameListener(frames.add);
            controller.addEventListener(events.add);
            await controller.prepareTerrainAhead();

            var maxEntities = 0;
            final geometryVersions = <int>{};
            const frameDeltas = [1 / 120, 1 / 60, 1 / 30, 0.08];
            // Real inputs and normal deaths bound these attempts. No actor,
            // collision, camera, resource, or authored-content overrides.
            for (
              var frame = 0;
              frame < 6000 &&
                  controller.tick < 7200 &&
                  !controller.snapshot.gameOver;
              frame++
            ) {
              actions.setMoveAxis(frame % 200 < 12 ? -1 : 1);
              if (frame % 32 == 0) {
                actions.triggerAction(RunnerGameplayAction.jump);
              }
              _cycleAction(actions, RunnerGameplayAction.primary, frame, 48, 8);
              _cycleAction(
                actions,
                RunnerGameplayAction.projectile,
                frame,
                110,
                17,
              );
              _cycleAction(
                actions,
                RunnerGameplayAction.secondary,
                frame,
                180,
                12,
              );
              _cycleAction(
                actions,
                RunnerGameplayAction.mobility,
                frame,
                220,
                5,
              );
              if (frame % 240 == 0) {
                actions.triggerAction(RunnerGameplayAction.spell);
              }
              if (frame % 110 < 17) actions.setAimDir(0.8, -0.6);

              if (frame % 113 == 55) {
                actions.cancelAll();
                controller.setPaused(true);
                final pausedTick = controller.tick;
                controller.advanceFrame(60);
                expect(controller.tick, pausedTick);
                controller.setPaused(false);
              }
              actions.pumpHeldInputs();
              controller.advanceFrame(
                frame % 97 == 0
                    ? 0.25
                    : frameDeltas[frame % frameDeltas.length],
              );
              final snapshot = controller.snapshot;
              _checkFiniteState(snapshot);
              maxEntities = snapshot.entities.length > maxEntities
                  ? snapshot.entities.length
                  : maxEntities;
              final geometry = snapshot.stagedTerrainRenderSnapshot;
              if (geometry != null) {
                geometryVersions.add(geometry.geometryVersion);
              }
              checkpoints[snapshot.tick] = _signature(snapshot);
            }
            final endedNaturally = controller.snapshot.gameOver;
            controller.giveUp();
            final liveEnd = controller.lastRunEndedEvent!;
            expect(events.whereType<RunEndedEvent>(), hasLength(1));
            expect(frames, hasLength(controller.tick));

            final replay = createCore();
            final replayEvents = <GameEvent>[];
            for (final frame in frames) {
              replay.applyCommands(ReplayCommandCodec.commandsFromFrame(frame));
              replay.stepOneTick();
              replayEvents.addAll(replay.drainEvents());
              if (checkpoints[frame.tick] case final expected?) {
                expect(
                  _signature(replay.buildSnapshot()),
                  expected,
                  reason: 'Replay diverged at tick ${frame.tick}',
                );
              }
            }
            if (!endedNaturally) {
              replay.giveUp();
              replayEvents.addAll(replay.drainEvents());
            }
            final replayEnd = replayEvents.whereType<RunEndedEvent>().single;
            expect(
              _signature(replay.buildSnapshot()),
              _signature(controller.snapshot),
            );
            expect(
              replayEvents.map((event) => event.runtimeType),
              events.map((event) => event.runtimeType),
            );
            expect(_endSignature(replayEnd), _endSignature(liveEnd));
            // These horizons describe autonomous attempts, not a claim that
            // the bot completes a level or that all authored seams are covered.
            // ignore: avoid_print
            print(
              'SHOWCASE_RUN ${levelId.name}/${character.id.name}/$seed '
              'ticks=${controller.tick} distance=${liveEnd.distance} '
              'maxEntities=$maxEntities geometryVersions=${geometryVersions.length} '
              'events=${events.length} end=${liveEnd.reason.name}',
            );
          },
          timeout: const Timeout(Duration(minutes: 2)),
        );
      }
    }
  }
}

void _cycleAction(
  RunnerSemanticActionDispatcher actions,
  RunnerGameplayAction action,
  int frame,
  int period,
  int releaseAt,
) {
  if (frame % period == 0) actions.beginAction(action);
  if (frame % period == releaseAt) actions.releaseAction(action);
}

AbilityInputMode _inputMode(
  GameStateSnapshot snapshot,
  RunnerGameplayAction action,
) => switch (action) {
  RunnerGameplayAction.primary => snapshot.hud.meleeInputMode,
  RunnerGameplayAction.secondary => snapshot.hud.secondaryInputMode,
  RunnerGameplayAction.projectile => snapshot.hud.projectileInputMode,
  RunnerGameplayAction.mobility => snapshot.hud.mobilityInputMode,
  _ => AbilityInputMode.tap,
};

void _checkFiniteState(GameStateSnapshot snapshot) {
  expect(
    [
      snapshot.distance,
      snapshot.camera.centerX,
      snapshot.camera.centerY,
      snapshot.hud.hp,
      snapshot.hud.mana,
      snapshot.hud.stamina,
      for (final entity in snapshot.entities) ...[
        entity.pos.x,
        entity.pos.y,
        if (entity.vel case final velocity?) ...[velocity.x, velocity.y],
        entity.rotationRad,
      ],
    ].every((value) => value.isFinite),
    isTrue,
  );
  expect(
    snapshot.entities.map((entity) => entity.id).toSet(),
    hasLength(snapshot.entities.length),
  );
}

List<Object?> _signature(GameStateSnapshot snapshot) => [
  snapshot.tick,
  snapshot.paused,
  snapshot.gameOver,
  snapshot.distance,
  snapshot.camera.centerX,
  snapshot.camera.centerY,
  snapshot.hud.hp,
  snapshot.hud.mana,
  snapshot.hud.stamina,
  snapshot.hud.collectibles,
  snapshot.hud.collectibleScore,
  snapshot.stagedTerrainRenderSnapshot?.geometryVersion,
  for (final entity in snapshot.entities)
    (
      entity.id,
      entity.kind,
      entity.pos.x,
      entity.pos.y,
      entity.vel?.x,
      entity.vel?.y,
      entity.projectileId,
      entity.rotationRad,
      entity.anim,
      entity.animFrame,
      entity.facing,
      entity.grounded,
      entity.statusVisualMask,
    ),
  for (final trap in snapshot.traps)
    (trap.source.runtimeId, trap.phase, trap.frameIndex),
];

List<Object?> _endSignature(RunEndedEvent event) => [
  event.tick,
  event.reason,
  event.distance,
  event.goldEarned,
  event.stats.collectibles,
  event.stats.collectibleScore,
  event.stats.enemyKillCounts,
  event.stats.rescuedNpcs,
  event.stats.rescuePoints,
  event.deathInfo?.kind,
  event.deathInfo?.enemyId,
  event.deathInfo?.projectileId,
];
