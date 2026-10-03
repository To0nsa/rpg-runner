import 'dart:math' as math;
import 'dart:collection';

import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_id.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/snapshots/actor_frame_snapshot.dart';
import 'package:flutter/foundation.dart';

import 'replay_command_codec.dart';

/// Synchronous deterministic replay engine for offline use and ghost workers.
/// Real-time routes consume BufferedGhostPlayback; they never step this Core
/// on the native UI isolate. All commands and events retain their recorded tick.
class GhostPlaybackRunner {
  GhostPlaybackRunner._({
    required this.replayBlob,
    required GameCore core,
    required Map<int, ReplayCommandFrameV1> frameByTick,
  }) : _core = core,
       _frameByTick = frameByTick {
    _snapshot = _captureSnapshot();
    _previousSnapshot = _snapshot;
  }

  factory GhostPlaybackRunner.fromReplayBlob(ReplayBlobV1 replayBlob) {
    final levelId = _enumByName(
      LevelId.values,
      replayBlob.levelId,
      fieldName: 'replayBlob.levelId',
    );
    LevelRegistry.requireAvailable(levelId);
    final characterId = _enumByName(
      PlayerCharacterId.values,
      replayBlob.playerCharacterId,
      fieldName: 'replayBlob.playerCharacterId',
    );
    final loadout = _loadoutFromSnapshot(replayBlob.loadoutSnapshot);
    final core = GameCore(
      seed: replayBlob.seed,
      runId: 1,
      tickHz: replayBlob.tickHz,
      levelDefinition: LevelRegistry.byId(levelId),
      playerCharacter: PlayerCharacterRegistry.resolve(characterId),
      equippedLoadoutOverride: loadout,
    );
    final frameByTick = <int, ReplayCommandFrameV1>{
      for (final frame in replayBlob.commandStream) frame.tick: frame,
    };
    return GhostPlaybackRunner._(
      replayBlob: replayBlob,
      core: core,
      frameByTick: frameByTick,
    );
  }

  final ReplayBlobV1 replayBlob;
  final GameCore _core;
  bool _disposed = false;

  /// Prepares upcoming terrain before real-time playback; offline replay may
  /// omit this without changing any commands, snapshots, or run results.
  Future<void> prepareTerrainAhead() =>
      _disposed ? Future<void>.value() : _core.prepareTerrainAhead();

  /// Releases background terrain work when the owning run or ghost closes.
  void dispose() {
    _disposed = true;
    _core.stopTerrainPreparation();
  }

  final Map<int, ReplayCommandFrameV1> _frameByTick;
  late ActorFrameSnapshot _snapshot;
  late ActorFrameSnapshot _previousSnapshot;
  final List<GameEvent> _drainedEvents = <GameEvent>[];
  late final List<GameEvent> _eventsView = UnmodifiableListView(_drainedEvents);
  int _snapshotBuildCount = 0;

  /// Projections since construction, for checking the catch-up allocation bound.
  @visibleForTesting
  int get debugSnapshotBuildCount => _snapshotBuildCount;

  ActorFrameSnapshot _captureSnapshot() {
    _snapshotBuildCount += 1;
    return _core.buildActorFrameSnapshot();
  }

  int _lastAdvancedTick = 0;
  RunEndedEvent? _runEndedEvent;
  bool _completed = false;

  /// Current immutable snapshot of the ghost simulation.
  ///
  /// This is render-only data; gameplay authority remains in the live run.
  ActorFrameSnapshot get snapshot => _snapshot;

  /// Adjacent previous tick while active; equals [snapshot] at start/completion.
  ActorFrameSnapshot get previousSnapshot => _previousSnapshot;

  int get tick => _core.tick;
  bool get isComplete => _completed;
  double get distance => _snapshot.distance;
  RunEndedEvent? get runEndedEvent => _runEndedEvent;

  /// Read-only view of events drained from the ghost core since the last
  /// [clearDrainedEvents] call.
  List<GameEvent> get drainedEvents => _eventsView;

  /// Clears buffered drained events after render consumers process them.
  void clearDrainedEvents() {
    _drainedEvents.clear();
  }

  /// Replays all commands through [targetTick], projecting only the final pair.
  ///
  /// Completion freezes interpolation at the terminal snapshot; no gameplay
  /// ticks or transient events are skipped when catching up after a hitch.
  void advanceToTick(int targetTick) {
    if (_completed || _disposed) {
      return;
    }
    final clampedTarget = math.max(
      0,
      math.min(targetTick, replayBlob.totalTicks),
    );
    if (clampedTarget <= _lastAdvancedTick) {
      _finalizeIfAtReplayEnd();
      return;
    }
    for (
      var nextTick = _lastAdvancedTick + 1;
      nextTick <= clampedTarget;
      nextTick += 1
    ) {
      final frame = _frameByTick[nextTick];
      final commands = frame == null
          ? const <Command>[]
          : ReplayCommandCodec.commandsFromFrame(frame);
      _core.applyCommands(commands);
      _core.stepOneTick();
      _lastAdvancedTick = nextTick;
      _drainCoreEvents();
      if (_runEndedEvent != null || _core.gameOver) {
        _complete();
        return;
      }
      if (_lastAdvancedTick >= replayBlob.totalTicks) {
        _finalizeIfAtReplayEnd();
        return;
      }
      if (nextTick >= clampedTarget - 1) {
        _previousSnapshot = _snapshot;
        _snapshot = _captureSnapshot();
      }
    }
    _finalizeIfAtReplayEnd();
  }

  void advanceToEnd() {
    advanceToTick(replayBlob.totalTicks);
    _finalizeIfAtReplayEnd();
  }

  void _finalizeIfAtReplayEnd() {
    if (_completed || _disposed || _lastAdvancedTick < replayBlob.totalTicks) {
      return;
    }
    if (!_core.gameOver) {
      _core.giveUp();
    }
    _drainCoreEvents();
    _complete();
  }

  void _complete() {
    _snapshot = _captureSnapshot();
    _previousSnapshot = _snapshot;
    _completed = true;
    dispose();
  }

  void _drainCoreEvents() {
    for (final event in _core.drainEvents()) {
      _drainedEvents.add(event);
      if (event is RunEndedEvent) {
        _runEndedEvent = event;
      }
    }
  }
}

T _enumByName<T extends Enum>(
  List<T> values,
  String raw, {
  required String fieldName,
}) {
  for (final value in values) {
    if (value.name == raw) {
      return value;
    }
  }
  throw ArgumentError.value(raw, fieldName, 'Unsupported enum value.');
}

EquippedLoadoutDef _loadoutFromSnapshot(Map<String, Object?> snapshot) {
  return EquippedLoadoutDef(
    mask: _requiredInt(snapshot, 'mask'),
    mainWeaponId: _enumByName(
      WeaponId.values,
      _requiredString(snapshot, 'mainWeaponId'),
      fieldName: 'loadoutSnapshot.mainWeaponId',
    ),
    offhandWeaponId: _enumByName(
      WeaponId.values,
      _requiredString(snapshot, 'offhandWeaponId'),
      fieldName: 'loadoutSnapshot.offhandWeaponId',
    ),
    spellBookId: _enumByName(
      SpellBookId.values,
      _requiredString(snapshot, 'spellBookId'),
      fieldName: 'loadoutSnapshot.spellBookId',
    ),
    projectileSlotSpellId: _enumByName(
      playerEquippableProjectileIds,
      _requiredString(snapshot, 'projectileSlotSpellId'),
      fieldName: 'loadoutSnapshot.projectileSlotSpellId',
    ),
    accessoryId: _enumByName(
      AccessoryId.values,
      _requiredString(snapshot, 'accessoryId'),
      fieldName: 'loadoutSnapshot.accessoryId',
    ),
    abilityPrimaryId: _requiredString(snapshot, 'abilityPrimaryId'),
    abilitySecondaryId: _requiredString(snapshot, 'abilitySecondaryId'),
    abilityProjectileId: _requiredString(snapshot, 'abilityProjectileId'),
    abilitySpellId: _requiredString(snapshot, 'abilitySpellId'),
    abilityMobilityId: _requiredString(snapshot, 'abilityMobilityId'),
    abilityJumpId: _requiredString(snapshot, 'abilityJumpId'),
  );
}

int _requiredInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw ArgumentError.value(value, 'loadoutSnapshot.$key', 'Must be integer.');
}

String _requiredString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw ArgumentError.value(value, 'loadoutSnapshot.$key', 'Must be string.');
}
