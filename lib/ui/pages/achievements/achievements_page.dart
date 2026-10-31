import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/gold_display.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app/app_state.dart';
import '../../theme/ui_tokens.dart';
import 'achievement_presentation.dart';
import 'achievement_tile.dart';
import 'achievement_claim_action.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});
  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    final app = context.read<AppState>();
    final uid = app.authSession.userId;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await app.refreshAchievements();
    } catch (_) {
      if (mounted && app.authSession.userId == uid) {
        setState(
          () => _error =
              'Unable to load achievements. Reopen this page to retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _claim(String? id) async {
    final app = context.read<AppState>();
    final uid = app.authSession.userId;
    try {
      await app.claimAchievements(achievementId: id);
    } catch (_) {
      if (!mounted || app.authSession.userId != uid) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to claim rewards. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ui = context.ui;
    final progress = app.progression.achievements;
    return MenuScaffold(
      title: 'Hall of Honour',
      appBarActions: [
        Padding(
          padding: EdgeInsets.only(right: ui.space.md),
          child: GoldDisplay(gold: app.displayedGold),
        ),
      ],
      child: MenuLayout(
        maxWidth: 1000,
        child: KeyedSubtree(
          key: PageStorageKey(app.authSession.userId),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (progress.entries
                      .where((entry) => entry.claimableGold > 0)
                      .length >
                  1) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: AchievementClaimAction(
                    all: true,
                    gold: progress.claimableGold,
                    onPressed: app.achievementsClaiming
                        ? null
                        : () => _claim(null),
                  ),
                ),
                SizedBox(height: ui.space.sm),
              ],
              if (_error != null)
                Padding(
                  padding: EdgeInsets.only(bottom: ui.space.sm),
                  child: Text(
                    _error!,
                    style: ui.text.body.copyWith(color: ui.colors.danger),
                  ),
                ),
              if (!app.achievementsAvailable)
                Text(
                  'Achievements are unavailable in Developer Practice.',
                  style: ui.text.body,
                )
              else if (progress.entries.isEmpty)
                Text(
                  _refreshing
                      ? 'Loading achievements…'
                      : 'Achievements are not available yet.',
                  style: ui.text.body,
                )
              else
                for (final entry in progress.entries)
                  if (AchievementPresentation.forId(entry.id)
                      case final presentation?)
                    AchievementTile(
                      key: ValueKey('achievement-${entry.id}'),
                      entry: entry,
                      presentation: presentation,
                      claiming: app.achievementsClaiming,
                      onClaim: () => _claim(entry.id),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
