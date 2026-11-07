import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:runner_core/players/player_character_registry.dart';

import '../../components/menu_layout.dart';
import '../../app/ui_routes.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app/app_state.dart';
import '../../theme/ui_tokens.dart';
import 'gears_tab.dart';
import 'skills_tab.dart';
import 'training_field_tab.dart';

class LoadoutSetupPage extends StatefulWidget {
  const LoadoutSetupPage({super.key});

  @override
  State<LoadoutSetupPage> createState() => _LoadoutSetupPageState();
}

class _LoadoutSetupPageState extends State<LoadoutSetupPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this)..addListener(_onTabChanged);
  }

  void _onTabChanged() => setState(() {});

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final characterId = context.watch<AppState>().selection.selectedCharacterId;
    final selectedDef = PlayerCharacterRegistry.resolve(characterId);

    return MenuScaffold(
      overlayAppBar: _tabs.index == 2,
      appBarActions: [
        TextButton.icon(
          onPressed: () =>
              Navigator.of(context)
                  .pushReplacementNamed(UiRoutes.selectCharacter),
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: Text(selectedDef.displayName),
        ),
      ],
      appBarTitle: SizedBox(
        height: 44,
        child: TabBar(
          controller: _tabs,
          dividerColor: ui.colors.outline.withValues(alpha: 0.35),
          indicatorColor: Colors.transparent,
          labelColor: ui.colors.accentStrong,
          unselectedLabelColor: ui.colors.textPrimary.withValues(alpha: 0.5),
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
            Tab(
              child: _LoadoutTopTabLabel(
                icon: Icons.sports_martial_arts,
                text: 'Training Field',
              ),
            ),
          ],
        ),
      ),
      centerAppBarTitle: true,
      child: _tabs.index == 2
          ? TrainingFieldTab(key: ValueKey(characterId))
          : MenuLayout(
              scrollable: false,
              child: _tabs.index == 0
                  ? GearsTab(
                      key: ValueKey(characterId),
                      characterId: selectedDef.id,
                    )
                  : SkillsBar(
                      key: ValueKey(characterId),
                      characterId: selectedDef.id,
                    ),
            ),
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
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text.toUpperCase()),
          ),
        ),
      ],
    );
  }
}
