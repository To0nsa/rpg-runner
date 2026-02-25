import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/players/player_character_definition.dart';
import '../../../core/players/player_character_registry.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app_state.dart';
import '../../theme/ui_tokens.dart';
import 'gears_tab.dart';
import 'skills_tab.dart';

// Keep multi-character backend logic intact; UI currently exposes only primary.
const List<PlayerCharacterDefinition> _loadoutSetupUiCharacters = [
  PlayerCharacterRegistry.eloise,
];

class LoadoutSetupPage extends StatefulWidget {
  const LoadoutSetupPage({super.key});

  @override
  State<LoadoutSetupPage> createState() => _LoadoutSetupPageState();
}

class _LoadoutSetupPageState extends State<LoadoutSetupPage> {
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final appState = context.read<AppState>();
    final selection = appState.selection;
    final defs = _loadoutSetupUiCharacters;
    if (defs.first.id != selection.selectedCharacterId) {
      unawaited(appState.setCharacter(defs.first.id));
    }
    _seeded = true;
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final selectedDef = _loadoutSetupUiCharacters.first;

    return DefaultTabController(
      length: 2,
      initialIndex: 0,
      child: MenuScaffold(
        appBarTitle: TabBar(
          labelColor: ui.colors.textPrimary,
          unselectedLabelColor: ui.colors.textMuted,
          labelStyle: ui.text.headline,
          indicatorColor: ui.colors.accent,
          tabs: const [
            Tab(text: 'Gear'),
            Tab(text: 'Skills'),
          ],
        ),
        child: MenuLayout(
          scrollable: false,
          child: _LoadoutSetupBody(characterId: selectedDef.id),
        ),
      ),
    );
  }
}

class _LoadoutSetupBody extends StatelessWidget {
  const _LoadoutSetupBody({required this.characterId});

  final PlayerCharacterId characterId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: TabBarView(
            // Keep setup tab selection explicit: tabs change via click/tap only.
            physics: const NeverScrollableScrollPhysics(),
            children: [
              GearsTab(characterId: characterId),
              SkillsBar(characterId: characterId),
            ],
          ),
        ),
      ],
    );
  }
}
