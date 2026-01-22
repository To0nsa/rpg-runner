import 'package:flutter/material.dart';

import '../components/menu_button.dart';
import '../components/menu_scaffold.dart';
import 'credits_page.dart';
import 'game_hub_page.dart';

/// The production main menu for the game.
///
/// Displays the game title and navigation buttons to Start and Credits.
class MainMenuPage extends StatelessWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuScaffold(
      showAppBar: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Game title
            const Text(
              'rpg-runner',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 64),

            // Start button
            MenuButton(
              label: 'START',
              onPressed: () => _navigateTo(context, const GameHubPage()),
            ),
            const SizedBox(height: 16),

            // Credits button
            MenuButton(
              label: 'CREDITS',
              onPressed: () => _navigateTo(context, const CreditsPage()),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => page),
    );
  }
}
