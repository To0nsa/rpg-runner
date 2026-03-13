import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import '../state/selection_state.dart';

class UiRoutes {
  const UiRoutes._();

  static const String brandSplash = '/brand_splash';
  static const String loader = '/loader';
  static const String hub = '/hub';
  static const String setupProfileName = '/setup/profile-name';
  static const String setupLevel = '/setup/level';
  static const String setupLoadout = '/setup/loadout';
  static const String profile = '/profile';
  static const String loadoutLab = '/lab';
  static const String leaderboards = '/leaderboards';
  static const String options = '/meta/options';
  static const String library = '/meta/library';
  static const String town = '/meta/town';
  static const String messages = '/meta/messages';
  static const String support = '/meta/support';
  static const String credits = '/credits';
  static const String run = '/run';
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
  });

  final String runSessionId;
  final int runId;
  final int seed;
  final LevelId levelId;
  final PlayerCharacterId playerCharacterId;
  final RunMode runMode;
  final EquippedLoadoutDef equippedLoadout;
}
