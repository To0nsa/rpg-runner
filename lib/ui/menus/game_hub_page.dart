import 'package:flutter/material.dart';

import '../components/menu_button.dart';
import '../components/menu_scaffold.dart';
import 'character_select_page.dart';
import 'library_page.dart';
import 'options_page.dart';
import 'runner_menu_page.dart';
import 'store_page.dart';

/// Game hub page with navigation to all game features.
///
/// Displays 5 menu buttons on the left side:
/// - Character Selection
/// - Level Selection
/// - Library
/// - Store
/// - Options
class GameHubPage extends StatelessWidget {
  const GameHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuScaffold(
      showAppBar: false,
      child: Row(
        children: [
          // Left half - navigation buttons
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MenuButton(
                    label: 'CHARACTER',
                    onPressed: () => _navigateTo(
                      context,
                      const CharacterSelectPage(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  MenuButton(
                    label: 'LEVELS',
                    onPressed: () => _navigateTo(
                      context,
                      const RunnerMenuPage(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  MenuButton(
                    label: 'LIBRARY',
                    onPressed: () => _navigateTo(
                      context,
                      const LibraryPage(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  MenuButton(
                    label: 'STORE',
                    onPressed: () => _navigateTo(
                      context,
                      const StorePage(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  MenuButton(
                    label: 'OPTIONS',
                    onPressed: () => _navigateTo(
                      context,
                      const OptionsPage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right half - reserved for future content (preview, character display, etc.)
          const Expanded(
            child: SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => page),
    );
  }
}
