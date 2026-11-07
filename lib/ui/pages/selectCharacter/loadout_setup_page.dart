import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:runner_core/players/player_character_registry.dart';

import '../../components/menu_layout.dart';
import 'build_name_action.dart';
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
    final trainingActive = _tabs.index == 2;
    // Hidden editors keep the same viewport while training draws under the bar,
    // so their scroll positions are not clamped by a temporary size change.
    final editorTopInset = trainingActive
        ? MediaQuery.paddingOf(context).top + kToolbarHeight
        : 0.0;

    // Rename owns a separate dialog route that handles the keyboard. Keep the
    // fixed-height gear/skills layout behind that modal at its normal size.
    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: MenuScaffold(
        overlayAppBar: trainingActive,
        appBarActions: const [BuildNameAction()],
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
        child: IndexedStack(
          key: ValueKey(characterId),
          index: _tabs.index,
          sizing: StackFit.expand,
          children: [
            for (final (index, tab) in <(int, Widget)>[
              (0, GearsTab(characterId: selectedDef.id)),
              (1, SkillsBar(characterId: selectedDef.id)),
            ])
              TickerMode(
                enabled: _tabs.index == index,
                child: ExcludeFocus(
                  excluding: _tabs.index != index,
                  child: Padding(
                    padding: EdgeInsets.only(top: editorTopInset),
                    child: MenuLayout(scrollable: false, child: tab),
                  ),
                ),
              ),
            // Training owns a disposable session; only the editors are retained.
            if (trainingActive)
              const TrainingFieldTab()
            else
              const SizedBox.shrink(),
          ],
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
