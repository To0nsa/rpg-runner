import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';

import '../../components/menu_layout.dart';
import 'build_name_action.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app/app_state.dart';
import '../../theme/ui_tokens.dart';
import 'gears_tab.dart';
import 'skills_tab.dart';
import 'training_field_tab.dart';

/// Pins editing to a saved slot without changing the next-run selection.
class LoadoutSetupArgs {
  const LoadoutSetupArgs({required this.characterId, required this.buildIndex});
  final PlayerCharacterId characterId;
  final int buildIndex;
}

class LoadoutSetupPage extends StatefulWidget {
  const LoadoutSetupPage({super.key, this.args});
  final LoadoutSetupArgs? args;

  @override
  State<LoadoutSetupPage> createState() => _LoadoutSetupPageState();
}

class _LoadoutSetupPageState extends State<LoadoutSetupPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  LoadoutSetupArgs? _target;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selection = context.read<AppState>().selection;
    _target ??=
        widget.args ??
        LoadoutSetupArgs(
          characterId: selection.selectedCharacterId,
          buildIndex: selection.selectedBuildIndexFor(
            selection.selectedCharacterId,
          ),
        );
  }

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
    final app = context.watch<AppState>();
    final characterId = _target!.characterId;
    final buildIndex = _target!.buildIndex;
    if (!app.isCharacterUnlocked(characterId) ||
        !app.isBuildUnlocked(buildIndex)) {
      return MenuScaffold(
        child: Center(
          child: Text(context.l10n.uiCouldNotSaveThisSelectionPleaseTryAgain),
        ),
      );
    }
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
        appBarActions: [
          BuildNameAction(characterId: characterId, buildIndex: buildIndex),
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
            tabs: [
              Tab(
                child: _LoadoutTopTabLabel(
                  icon: Icons.shield_outlined,
                  text: context.l10n.uiGear,
                ),
              ),
              Tab(
                child: _LoadoutTopTabLabel(
                  icon: Icons.auto_awesome_outlined,
                  text: context.l10n.uiSkills,
                ),
              ),
              Tab(
                child: _LoadoutTopTabLabel(
                  icon: Icons.sports_martial_arts,
                  text: context.l10n.uiTrainingField,
                ),
              ),
            ],
          ),
        ),
        centerAppBarTitle: true,
        child: IndexedStack(
          key: ValueKey((characterId, buildIndex)),
          index: _tabs.index,
          sizing: StackFit.expand,
          children: [
            for (final (index, tab) in <(int, Widget)>[
              (
                0,
                GearsTab(characterId: selectedDef.id, buildIndex: buildIndex),
              ),
              (
                1,
                SkillsBar(characterId: selectedDef.id, buildIndex: buildIndex),
              ),
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
              TrainingFieldTab(characterId: characterId, buildIndex: buildIndex)
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
