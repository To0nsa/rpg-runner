import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bootstrap/loader_page.dart';
import '../bootstrap/brand_splash_screen.dart';
import '../components/placeholder_page.dart';
import '../pages/hub/play_hub_page.dart';
import '../pages/hub/run_start_bootstrap_page.dart';
import '../pages/leaderboards/leaderboards_page.dart';
import '../pages/town/town_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/selectLevel/level_setup_page.dart';
import '../pages/selectCharacter/loadout_setup_page.dart';
import '../bootstrap/profile_name_setup_page.dart';
import '../runner_game_route.dart';
import 'ui_routes.dart';

class UiRouter {
  const UiRouter._();

  static Route<void> _pageRoute(RouteSettings settings, Widget page) {
    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }

  static T _argsOr<T>(Object? args, T fallback) {
    return args is T ? args : fallback;
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case UiRoutes.brandSplash:
        return _pageRoute(settings, const BrandSplashScreen());
      case UiRoutes.loader:
        final args = _argsOr(settings.arguments, const LoaderArgs());
        return _pageRoute(settings, LoaderPage(args: args));
      case UiRoutes.hub:
        return _pageRoute(settings, const PlayHubPage());
      case UiRoutes.setupLevel:
        return _pageRoute(settings, const LevelSetupPage());
      case UiRoutes.setupLoadout:
        return _pageRoute(settings, const LoadoutSetupPage());
      case UiRoutes.setupProfileName:
        return _pageRoute(settings, const ProfileNameSetupPage());
      case UiRoutes.profile:
        return _pageRoute(settings, const ProfilePage());
      case UiRoutes.leaderboards:
        return _pageRoute(settings, const LeaderboardsPage());
      case UiRoutes.options:
        return _pageRoute(settings, const PlaceholderPage(title: 'Options'));
      case UiRoutes.town:
        return _pageRoute(settings, const TownPage());
      case UiRoutes.messages:
        return _pageRoute(settings, const PlaceholderPage(title: 'Messages'));
      case UiRoutes.runBootstrap:
        final bootstrapArgs = _argsOr(
          settings.arguments,
          const RunStartBootstrapArgs(),
        );
        return _pageRoute(settings, RunStartBootstrapPage(args: bootstrapArgs));
      case UiRoutes.run:
        final args = settings.arguments;
        if (args is RunStartDescriptor) {
          return createRunnerGameRoute(
            runSessionId: args.runSessionId,
            runId: args.runId,
            seed: args.seed,
            levelId: args.levelId,
            playerCharacterId: args.playerCharacterId,
            runMode: args.runMode,
            equippedLoadout: args.equippedLoadout,
            boardId: args.boardId,
            boardKey: args.boardKey,
            ghostReplayBootstrap: args.ghostReplayBootstrap,
            settings: settings,
            restoreOrientations: const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ],
            restoreSystemUiMode: SystemUiMode.immersiveSticky,
          );
        }
        return _pageRoute(settings, const PlayHubPage());
      default:
        return _pageRoute(settings, const PlayHubPage());
    }
  }
}
