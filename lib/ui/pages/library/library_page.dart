import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/enemies/enemy_id.dart';

import '../../codex/codex_catalog.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app/app_state.dart';
import '../../state/ownership/codex_progress.dart';
import '../../theme/ui_tokens.dart';
import 'codex_entry_page.dart';
import 'codex_widgets.dart';

/// Reads settled account progress; browsing never grants discoveries locally.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.select<AppState, CodexProgress>(
      (app) => app.progression.codex,
    );
    final ui = context.ui;
    return DefaultTabController(
      length: 3,
      child: MenuScaffold(
        title: 'Library',
        background: ColoredBox(color: ui.colors.background),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              TabBar(
                labelColor: ui.colors.textPrimary,
                unselectedLabelColor: ui.colors.textMuted,
                indicatorColor: ui.colors.accentStrong,
                tabs: const [
                  Tab(text: 'Bestiary'),
                  Tab(text: 'Places'),
                  Tab(text: 'Journal'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _Bestiary(progress: progress),
                    _Places(progress: progress),
                    const CodexReadingView(
                      title: CodexCatalog.openingTitle,
                      subtitle: 'Éloïse’s expedition • Six centuries before Les Soleils d’or',
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
    final entries = EnemyId.values
        .where(
          (id) => switch (_filter) {
            _EnemyFilter.all => true,
            _EnemyFilter.enemies => !id.isBoss,
            _EnemyFilter.bosses => id.isBoss,
          },
        )
        .toList();
    final unlocked = EnemyId.values
        .where((id) => CodexCatalog.enemyUnlocked(widget.progress, id))
        .length;
    return ListView(
      padding: EdgeInsets.all(ui.space.md),
      children: [
        Text(
          '$unlocked / ${EnemyId.values.length} entries discovered',
          style: ui.text.headline,
        ),
        SizedBox(height: ui.space.xs),
        Text(
          'Defeat an enemy 10 times, or a boss 5 times. Kills accumulate across validated runs and characters.',
          style: ui.text.body,
        ),
        SizedBox(height: ui.space.sm),
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
            category: id.isBoss
                ? 'Boss'
                : id.isBossSummon
                ? 'Summoned creature'
                : 'Enemy',
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

class _Places extends StatelessWidget {
  const _Places({required this.progress});
  final CodexProgress progress;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return ListView(
      padding: EdgeInsets.all(ui.space.md),
      children: [
        Text('Know the land', style: ui.text.headline),
        SizedBox(height: ui.space.xs),
        Text(
          'Reach the required score in one Competitive run on each level. Your best validated score is kept across seasons.',
          style: ui.text.body,
        ),
        SizedBox(height: ui.space.md),
        for (final id in CodexCatalog.levelScoreRequirements.keys)
          CodexEntryTile(
            key: ValueKey('codex-level-${id.name}'),
            title: CodexCatalog.levelName(id),
            category: 'Place',
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
