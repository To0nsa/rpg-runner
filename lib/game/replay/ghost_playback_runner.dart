import 'dart:math' as math;

import 'package:runner_core/abilities/ability_def.dart';
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

class GhostPlaybackRunner {
  GhostPlaybackRunner._({
    required this.replayBlob,
    required GameCore core,
    required Map<int, ReplayCommandFrameV1> frameByTick,
  }) : _core = core,
       _frameByTick = frameByTick;

  factory GhostPlaybackRunner.fromReplayBlob(ReplayBlobV1 replayBlob) {
    final levelId = _enumByName(
      LevelId.values,
      replayBlob.levelId,
      fieldName: 'replayBlob.levelId',
    );
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
  final Map<int, ReplayCommandFrameV1> _frameByTick;

  int _lastAdvancedTick = 0;
  RunEndedEvent? _runEndedEvent;
  bool _completed = false;

  int get tick => _core.tick;
  bool get isComplete => _completed;
  double get distance => _core.buildSnapshot().distance;
  RunEndedEvent? get runEndedEvent => _runEndedEvent;

  void advanceToTick(int targetTick) {
    if (_completed) {
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
          : _commandsFromReplayFrame(frame);
      _core.applyCommands(commands);
      _core.stepOneTick();
      _lastAdvancedTick = nextTick;
      _drainCoreEvents();
      if (_runEndedEvent != null || _core.gameOver) {
        _completed = true;
        return;
      }
    }
    _finalizeIfAtReplayEnd();
  }

  void advanceToEnd() {
    advanceToTick(replayBlob.totalTicks);
    _finalizeIfAtReplayEnd();
  }

  void _finalizeIfAtReplayEnd() {
    if (_completed || _lastAdvancedTick < replayBlob.totalTicks) {
      return;
    }
    if (!_core.gameOver) {
      _core.giveUp();
    }
    _drainCoreEvents();
    _completed = true;
  }

  void _drainCoreEvents() {
    for (final event in _core.drainEvents()) {
      if (event is RunEndedEvent) {
        _runEndedEvent = event;
      }
    }
  }

  static List<Command> _commandsFromReplayFrame(ReplayCommandFrameV1 frame) {
    final out = <Command>[];
    final tick = frame.tick;
    final moveAxis = frame.moveAxis;
    if (moveAxis != null && moveAxis != 0) {
      out.add(MoveAxisCommand(tick: tick, axis: moveAxis));
    }
    final aimDirX = frame.aimDirX;
    final aimDirY = frame.aimDirY;
    if (aimDirX != null && aimDirY != null) {
      out.add(AimDirCommand(tick: tick, x: aimDirX, y: aimDirY));
    }
    if (frame.jumpPressed) {
      out.add(JumpPressedCommand(tick: tick));
    }
    if (frame.dashPressed) {
      out.add(DashPressedCommand(tick: tick));
    }
    if (frame.strikePressed) {
      out.add(StrikePressedCommand(tick: tick));
    }
    if (frame.projectilePressed) {
      out.add(ProjectilePressedCommand(tick: tick));
    }
    if (frame.secondaryPressed) {
      out.add(SecondaryPressedCommand(tick: tick));
    }
    if (frame.spellPressed) {
      out.add(SpellPressedCommand(tick: tick));
    }
    final changedMask = frame.abilitySlotHeldChangedMask;
    if (changedMask != 0) {
      for (final slot in AbilitySlot.values) {
        final bit = 1 << slot.index;
        if ((changedMask & bit) == 0) {
          continue;
        }
        final held = (frame.abilitySlotHeldValueMask & bit) != 0;
        out.add(AbilitySlotHeldCommand(tick: tick, slot: slot, held: held));
      }
    }
    return out;
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
      ProjectileId.values,
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
