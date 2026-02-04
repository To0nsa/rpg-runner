import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bootstrap/loader_page.dart';
import '../bootstrap/brand_splash_screen.dart';
import '../pages/hub/play_hub_page.dart';
import '../pages/leaderboards/leaderboards_page.dart';
import '../pages/lab/loadout_lab_page.dart';
import '../pages/meta/credits_page.dart';
import '../pages/meta/town_page.dart';
import '../pages/meta/support_page.dart';
import '../pages/meta/library_page.dart';
import '../pages/meta/options_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/selectLevel/level_setup_page.dart';
import '../pages/selectCharacter/loadout_setup_page.dart';
import '../bootstrap/profile_name_setup_page.dart';
import '../runner_game_route.dart';
import 'ui_routes.dart';

class UiRouter {
  const UiRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case UiRoutes.brandSplash:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const BrandSplashScreen(),
        );
      case UiRoutes.loader:
        final args = settings.arguments is LoaderArgs
            ? settings.arguments as LoaderArgs
            : const LoaderArgs();
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => LoaderPage(args: args),
        );
      case UiRoutes.hub:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PlayHubPage(),
        );
      case UiRoutes.setupLevel:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LevelSetupPage(),
        );
      case UiRoutes.setupLoadout:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LoadoutSetupPage(),
        );
      case UiRoutes.setupProfileName:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ProfileNameSetupPage(),
        );
      case UiRoutes.profile:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ProfilePage(),
        );
      case UiRoutes.loadoutLab:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LoadoutLabPage(),
        );
      case UiRoutes.leaderboards:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LeaderboardsPage(),
        );
      case UiRoutes.options:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const OptionsPage(),
        );
      case UiRoutes.library:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LibraryPage(),
        );
      case UiRoutes.town:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const TownPage(),
        );
      case UiRoutes.support:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SupportPage(),
        );
      case UiRoutes.credits:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CreditsPage(),
        );
      case UiRoutes.run:
        final args = settings.arguments;
        if (args is RunStartArgs) {
          return createRunnerGameRoute(
            runId: args.runId,
            seed: args.seed,
            levelId: args.levelId,
            playerCharacterId: args.playerCharacterId,
            settings: settings,
            restoreOrientations: const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ],
            restoreSystemUiMode: SystemUiMode.immersiveSticky,
          );
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PlayHubPage(),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PlayHubPage(),
        );
    }
  }
}
