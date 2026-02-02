import '../../core/levels/level_id.dart';
import '../../core/players/player_character_definition.dart';
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
  static const String support = '/meta/support';
  static const String credits = '/credits';
  static const String run = '/run';
}

class LoaderArgs {
  const LoaderArgs({this.isResume = false});

  final bool isResume;
}

class RunStartArgs {
  const RunStartArgs({
    required this.runId,
    required this.seed,
    required this.levelId,
    required this.playerCharacterId,
    required this.runType,
  });

  final int runId;
  final int seed;
  final LevelId levelId;
  final PlayerCharacterId playerCharacterId;
  final RunType runType;
}
