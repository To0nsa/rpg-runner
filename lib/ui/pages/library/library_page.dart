import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/enemies/enemy_id.dart';

import '../../codex/codex_catalog.dart';
import '../../components/menu_scaffold.dart';
import '../../components/app_icon_button.dart';
import 'enemy_portrait.dart';
import '../../state/app/app_state.dart';
import '../../state/ownership/codex_progress.dart';
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
    final progress = context.select<AppState, CodexProgress>(
      (app) => app.progression.codex,
    );
    final ui = context.ui;
    return MenuScaffold(
      title: 'Library',
      background: ColoredBox(color: ui.colors.background),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showLabels = constraints.maxWidth >= 480;
            return Row(
              children: [
                SizedBox(
                  width: showLabels ? 96 : 64,
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final section in _LibrarySection.values)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: ui.space.xs,
                              ),
                              child: Semantics(
                                selected: section == _section,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: section == _section
                                        ? ui.colors.cardBackground
                                        : null,
                                    border: Border(
                                      left: BorderSide(
                                        width: 3,
                                        color: section == _section
                                            ? ui.colors.accentStrong
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: AppIconButton(
                                      icon: switch (section) {
                                        _LibrarySection.bestiary => Icons.pets,
                                        _LibrarySection.locations =>
                                          Icons.map_outlined,
                                        _LibrarySection.journal =>
                                          Icons.auto_stories_outlined,
                                      },
                                      tooltip: _sectionName(section),
                                      label: showLabels
                                          ? _sectionName(section)
                                          : null,
                                      onPressed: () =>
                                          setState(() => _section = section),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _section.index,
                    children: [
                      _Bestiary(progress: progress),
                      _Locations(progress: progress),
                      const CodexReadingView(
                        title: CodexCatalog.openingTitle,
                        subtitle: 'Éloïse’s expedition • Six centuries before Les Soleils d’or',
                        paragraphs: [CodexCatalog.opening],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
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

enum _EnemyFilter { all, enemies, bosses }

class _Bestiary extends StatefulWidget {
  const _Bestiary({required this.progress});
  final CodexProgress progress;
  @override
  State<_Bestiary> createState() => _BestiaryState();
}

class _BestiaryState extends State<_Bestiary> {
  _EnemyFilter _filter = _EnemyFilter.all;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final entries = CodexCatalog.bestiaryEntries
        .where(
          (id) => switch (_filter) {
            _EnemyFilter.all => true,
            _EnemyFilter.enemies => !id.isBoss,
            _EnemyFilter.bosses => id.isBoss,
          },
        )
        .toList();
    return ListView(
      key: const PageStorageKey('codex-bestiary'),
      padding: EdgeInsets.all(ui.space.sm),
      children: [
        Wrap(
          spacing: ui.space.xs,
          children: [
            for (final filter in _EnemyFilter.values)
              ChoiceChip(
                label: Text(switch (filter) {
                  _EnemyFilter.all => 'All',
                  _EnemyFilter.enemies => 'Enemies',
                  _EnemyFilter.bosses => 'Bosses',
                }),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
              ),
          ],
        ),
        SizedBox(height: ui.space.sm),
        for (final id in entries)
          CodexEntryTile(
            key: ValueKey('codex-enemy-${id.name}'),
            title: id.displayName,
            portrait: EnemyPortrait(enemy: id),
            current: widget.progress.enemyKills[id.name] ?? 0,
            requiredProgress: CodexCatalog.killsRequired(id),
            progressLabel: 'defeated',
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
  const _Locations({required this.progress});
  final CodexProgress progress;

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
