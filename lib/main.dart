import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'ui/menus/main_menu_page.dart';

/// Production app entry point for the rpg-runner game.
///
/// The runner can also be embedded in other Flutter apps via
/// `RunnerGameWidget` / `createRunnerGameRoute` (see `lib/runner.dart`).
/// Embedding apps should initialize Firebase (and any other services) themselves.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to landscape orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Hide status bar and navigation bar (immersive fullscreen)
  // Note: Also re-applied in MenuScaffold to handle navigation edge cases
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const RpgRunnerApp());
}

class RpgRunnerApp extends StatelessWidget {
  const RpgRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'rpg-runner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainMenuPage(),
    );
  }
}
