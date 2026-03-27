import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:run_protocol/board_key.dart';
import '../state/ownership/selection_state.dart';
import '../state/boards/ghost_replay_cache.dart';

class UiRoutes {
  const UiRoutes._();

  static const String brandSplash = '/brand_splash';
  static const String loader = '/loader';
  static const String hub = '/hub';
  static const String setupProfileName = '/setup/profile-name';
  static const String setupLevel = '/setup/level';
  static const String setupLoadout = '/setup/loadout';
  static const String profile = '/profile';
  static const String leaderboards = '/leaderboards';
  static const String options = '/meta/options';
  static const String town = '/meta/town';
  static const String messages = '/meta/messages';
  static const String runBootstrap = '/run/bootstrap';
  static const String run = '/run';
}

class RunStartBootstrapArgs {
  const RunStartBootstrapArgs({
    this.expectedMode,
    this.expectedLevelId,
    this.ghostEntryId,
  });

  final RunMode? expectedMode;
  final LevelId? expectedLevelId;
  final String? ghostEntryId;
}

class LoaderArgs {
  const LoaderArgs({this.isResume = false});

  final bool isResume;
}

class RunStartDescriptor {
  const RunStartDescriptor({
    required this.runSessionId,
    required this.runId,
    required this.seed,
    required this.levelId,
    required this.playerCharacterId,
    required this.runMode,
    required this.equippedLoadout,
    this.boardId,
    this.boardKey,
    this.ghostReplayBootstrap,
  });

  final String runSessionId;
  final int runId;
  final int seed;
  final LevelId levelId;
  final PlayerCharacterId playerCharacterId;
  final RunMode runMode;
  final EquippedLoadoutDef equippedLoadout;
  final String? boardId;
  final BoardKey? boardKey;
  final GhostReplayBootstrap? ghostReplayBootstrap;

  RunStartDescriptor copyWith({
    String? runSessionId,
    int? runId,
    int? seed,
    LevelId? levelId,
    PlayerCharacterId? playerCharacterId,
    RunMode? runMode,
    EquippedLoadoutDef? equippedLoadout,
    String? boardId,
    BoardKey? boardKey,
    GhostReplayBootstrap? ghostReplayBootstrap,
    bool clearGhostReplayBootstrap = false,
  }) {
    return RunStartDescriptor(
      runSessionId: runSessionId ?? this.runSessionId,
      runId: runId ?? this.runId,
      seed: seed ?? this.seed,
      levelId: levelId ?? this.levelId,
      playerCharacterId: playerCharacterId ?? this.playerCharacterId,
      runMode: runMode ?? this.runMode,
      equippedLoadout: equippedLoadout ?? this.equippedLoadout,
      boardId: boardId ?? this.boardId,
      boardKey: boardKey ?? this.boardKey,
      ghostReplayBootstrap: clearGhostReplayBootstrap
          ? null
          : (ghostReplayBootstrap ?? this.ghostReplayBootstrap),
    );
  }
}
