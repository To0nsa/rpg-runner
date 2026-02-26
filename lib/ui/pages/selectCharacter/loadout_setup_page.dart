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
    final segmentedRadius = BorderRadius.circular(ui.radii.md);
    final safeRight = MediaQuery.paddingOf(context).right;

    return DefaultTabController(
      length: 2,
      initialIndex: 0,
      child: MenuScaffold(
        appBarTitle: Padding(
          padding: EdgeInsets.only(right: safeRight + ui.space.sm),
          child: SizedBox(
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ui.colors.surface,
                borderRadius: segmentedRadius,
                border: Border.all(
                  color: ui.colors.outlineStrong,
                  width: ui.sizes.borderWidth / 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: segmentedRadius,
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: EdgeInsets.all(ui.space.xxs),
                  indicator: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(ui.radii.sm),
                  ),
                  splashBorderRadius: segmentedRadius,
                  labelColor: ui.colors.accentStrong,
                  unselectedLabelColor: ui.colors.background,
                  labelStyle: ui.text.label.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: ui.text.label.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: const [
                    Tab(
                      child: _LoadoutTopTabLabel(
                        icon: Icons.shield_outlined,
                        text: 'Gear',
                      ),
                    ),
                    Tab(
                      child: _LoadoutTopTabLabel(
                        icon: Icons.auto_awesome_outlined,
                        text: 'Skills',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        centerAppBarTitle: true,
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

class _LoadoutTopTabLabel extends StatelessWidget {
  const _LoadoutTopTabLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: ui.sizes.iconSize.sm),
        SizedBox(width: ui.space.xs),
        Text(text.toUpperCase()),
      ],
    );
  }
}
