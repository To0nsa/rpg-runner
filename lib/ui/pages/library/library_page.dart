import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/enemies/enemy_id.dart';

import '../../codex/codex_catalog.dart';
import '../../components/menu_scaffold.dart';
import '../../components/menu_icon_column.dart';
import 'enemy_portrait.dart';
import '../../state/app/app_state.dart';
import '../../state/ownership/codex_progress.dart';
import '../../state/ownership/enemy_defeats.dart';
import '../../state/ownership/progression_state.dart';
import '../../state/presentation/library_progress_tracker.dart';
import '../../theme/ui_tokens.dart';
import 'codex_entry_page.dart';
import 'codex_widgets.dart';

/// Reads settled account progress; browsing never grants discoveries locally.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

enum _LibrarySection { bestiary, locations, journal }

class _LibraryPageState extends State<LibraryPage> {
  _LibrarySection _section = _LibrarySection.bestiary;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final progress = context.select<AppState, ProgressionState>(
      (app) => app.progression,
    );
    final accountKey = '${app.authSession.userId}:${app.profileId}';
    final ui = context.ui;
    return MenuScaffold(
      title: 'Library · ${_sectionName(_section)}',
      background: ColoredBox(color: ui.colors.background),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: ui.space.lg),
          child: Row(
            children: [
              SingleChildScrollView(
                child: MenuIconColumn(
                  actions: [
                    for (final section in _LibrarySection.values)
                      MenuIconAction(
                        icon: switch (section) {
                          _LibrarySection.bestiary => Icons.pets,
                          _LibrarySection.locations => Icons.map_outlined,
                          _LibrarySection.journal =>
                            Icons.auto_stories_outlined,
                        },
                        tooltip: _sectionName(section),
                        selected: section == _section,
                        onPressed: () => setState(() => _section = section),
                      ),
                  ],
                ),
              ),
              SizedBox(width: ui.space.xs),
              Expanded(
                child: IndexedStack(
                  index: _section.index,
                  children: [
                    _Bestiary(
                      defeats: progress.enemyDefeats,
                      active: _section == _LibrarySection.bestiary,
                      tracker: app.libraryProgressTracker,
                      accountKey: accountKey,
                    ),
                    _Locations(
                      progress: progress.codex,
                      active: _section == _LibrarySection.locations,
                      tracker: app.libraryProgressTracker,
                      accountKey: accountKey,
                    ),
                    const CodexReadingView(
                      title: CodexCatalog.openingTitle,
                      subtitle: 'Éloïse of Elingen • Haute-Lothringen',
                      paragraphs: [CodexCatalog.opening],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sectionName(_LibrarySection section) => switch (section) {
    _LibrarySection.bestiary => 'Bestiary',
    _LibrarySection.locations => 'Locations',
    _LibrarySection.journal => 'Journal',
  };
}

class _Bestiary extends StatelessWidget {
  const _Bestiary({
    required this.defeats,
    required this.active,
    required this.tracker,
    required this.accountKey,
  });
  final EnemyDefeats defeats;
  final bool active;
  final LibraryProgressTracker tracker;
  final String accountKey;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return ListView(
      key: const PageStorageKey('codex-bestiary'),
      padding: EdgeInsets.all(ui.space.sm),
      children: [
        for (final id in CodexCatalog.bestiaryEntries)
          CodexEntryTile(
            key: ValueKey('codex-enemy-${id.name}'),
            title: id.displayName,
            portrait: EnemyPortrait(enemy: id),
            current: defeats.byEnemy[id.name] ?? 0,
            requiredProgress: CodexCatalog.killsRequired(id),
            progressLabel: 'defeated',
            active: active,
            tracker: tracker,
            accountKey: accountKey,
            progressKey: 'enemy:${id.name}',
            concealUntilUnlocked: true,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: RouteSettings(
                  name: '/meta/town/library/enemy/${id.name}',
                ),
                builder: (_) => CodexEntryPage.enemy(id),
              ),
            ),
          ),
      ],
    );
  }
}

class _Locations extends StatelessWidget {
  const _Locations({
    required this.progress,
    required this.active,
    required this.tracker,
    required this.accountKey,
  });
  final CodexProgress progress;
  final bool active;
  final LibraryProgressTracker tracker;
  final String accountKey;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return ListView(
      padding: EdgeInsets.all(ui.space.sm),
      children: [
        for (final id in CodexCatalog.levelScoreRequirements.keys)
          CodexEntryTile(
            key: ValueKey('codex-level-${id.name}'),
            title: CodexCatalog.levelName(id),
            portrait: Icon(
              Icons.landscape_outlined,
              color: ui.colors.accentStrong,
            ),
            current: progress.competitiveBestScores[id.name] ?? 0,
            requiredProgress: CodexCatalog.levelScoreRequirements[id]!,
            progressLabel: 'best Competitive score',
            active: active,
            tracker: tracker,
            accountKey: accountKey,
            progressKey: 'level:${id.name}',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: RouteSettings(
                  name: '/meta/town/library/level/${id.name}',
                ),
                builder: (_) => CodexEntryPage.level(id),
              ),
            ),
          ),
      ],
    );
  }
}
