import 'package:flutter/material.dart';
import 'package:runner_core/snapshots/campaign_snapshot.dart';

import '../../game/game_controller.dart';
import '../components/hud_frame.dart';
import '../l10n/app_localization.dart';
import '../theme/ui_hud_theme.dart';
import '../theme/ui_tokens.dart';

/// Core owns objective progress; this widget only tracks its completion display.
class CampaignHud extends StatefulWidget {
  const CampaignHud({
    super.key,
    required this.controller,
    this.showBlessingObjective = true,
  });
  final GameController controller;
  final bool showBlessingObjective;

  @override
  State<CampaignHud> createState() => _CampaignHudState();
}

class _CampaignHudState extends State<CampaignHud> {
  final _completedTicks = <CampaignObjective, int>{};
  int _lastTick = 0;
  String? _missionId;

  @override
  void initState() {
    super.initState();
    _observeSnapshot();
    widget.controller.addListener(_onSnapshot);
  }

  @override
  void didUpdateWidget(CampaignHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onSnapshot);
    _completedTicks.clear();
    _observeSnapshot();
    widget.controller.addListener(_onSnapshot);
  }

  void _observeSnapshot() {
    final snapshot = widget.controller.snapshot;
    final campaign = snapshot.campaign;
    if (campaign?.missionId != _missionId || snapshot.tick < _lastTick) {
      _completedTicks.clear();
    }
    for (final objective in CampaignObjective.values) {
      if (campaign?.isComplete(objective) == true) {
        _completedTicks.putIfAbsent(objective, () => snapshot.tick);
      } else {
        _completedTicks.remove(objective);
      }
    }
    _missionId = campaign?.missionId;
    _lastTick = snapshot.tick;
  }

  void _onSnapshot() => setState(_observeSnapshot);

  @override
  void dispose() {
    widget.controller.removeListener(_onSnapshot);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.controller.snapshot;
    final campaign = snapshot.campaign;
    if (campaign == null) return const SizedBox.shrink();
    // Committed gameplay time keeps tutorial, manual and lifecycle pauses from
    // consuming the completion acknowledgement. No wall-clock timer survives Play.
    Duration age(CampaignObjective objective) => Duration(
      microseconds:
          ((snapshot.tick - (_completedTicks[objective] ?? snapshot.tick)) *
                  Duration.microsecondsPerSecond /
                  widget.controller.tickHz)
              .round(),
    );
    return CampaignObjectivesPanel(
      campaign: campaign,
      playerX: snapshot.playerEntity?.pos.x ?? campaign.exitX,
      completedFor: age(CampaignObjective.firstCoin),
      blessingCompletedFor: age(CampaignObjective.blessing),
      showBlessingObjective: widget.showBlessingObjective,
    );
  }
}

/// Shared by live HUD and authoring; preview values do not age on a wall clock.
class CampaignObjectivesPanel extends StatelessWidget {
  const CampaignObjectivesPanel({
    super.key,
    required this.campaign,
    required this.playerX,
    this.completedFor = Duration.zero,
    this.blessingCompletedFor = Duration.zero,
    this.showBlessingObjective = true,
  });
  final CampaignSnapshot campaign;
  final double playerX;
  final Duration completedFor, blessingCompletedFor;
  final bool showBlessingObjective;

  static const completionHold = Duration(seconds: 3);
  static const completionFade = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    double opacity(CampaignObjective objective) {
      if (!campaign.isComplete(objective)) return 1;
      final age = objective == CampaignObjective.firstCoin
          ? completedFor
          : blessingCompletedFor;
      return (1 -
              (age - completionHold).inMicroseconds /
                  completionFade.inMicroseconds)
          .clamp(0.0, 1.0);
    }

    final objectives = [
      for (final objective in CampaignObjective.values)
        if (campaign.requires(objective) &&
            opacity(objective) > 0 &&
            (objective != CampaignObjective.blessing || showBlessingObjective))
          objective,
    ];
    final namedRequired = CampaignObjective.values
        .where(campaign.requires)
        .length;
    final otherRequired = campaign.required - namedRequired;
    final showOtherObjectives = namedRequired == 0 || otherRequired > 0;
    if (objectives.isEmpty && !showOtherObjectives) {
      return const SizedBox.shrink();
    }
    final panelOpacity = showOtherObjectives
        ? 1.0
        : objectives.map(opacity).reduce((a, b) => a > b ? a : b);

    final labelStyle = ui.text.body.copyWith(
      fontFamily: 'Inter',
      fontSize: 11,
      color: context.hudTheme.foreground,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget row(CampaignObjective objective) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            switch (objective) {
              CampaignObjective.firstCoin => context.l10n.campaignCollectCoin(
                collected: campaign.firstCoinCollected ? 1 : 0,
              ),
              CampaignObjective.blessing =>
                context.l10n.campaignReceiveBlessing(
                  received: campaign.blessingReceived ? 1 : 0,
                ),
            },
            style: labelStyle,
            textAlign: TextAlign.center,
          ),
        ),
        if (campaign.isComplete(objective)) ...[
          SizedBox(width: ui.space.xxs),
          Icon(Icons.check, size: 16, color: ui.colors.success),
        ],
      ],
    );
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        child: Opacity(
          opacity: panelOpacity,
          child: HudPanel(
            padding: EdgeInsets.symmetric(
              horizontal: ui.space.xs,
              vertical: ui.space.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final objective in objectives)
                  Opacity(
                    opacity: opacity(objective) / panelOpacity,
                    child: row(objective),
                  ),
                if (showOtherObjectives) ...[
                  if (objectives.isNotEmpty) SizedBox(height: ui.space.xxs),
                  Text(
                    context.l10n.campaignObjectives(
                      completed:
                          campaign.completed -
                          CampaignObjective.values
                              .where(
                                (o) =>
                                    campaign.requires(o) &&
                                    campaign.isComplete(o),
                              )
                              .length,
                      required: otherRequired,
                    ),
                    style: labelStyle,
                    textAlign: TextAlign.center,
                  ),
                  if (campaign.exitReady)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          campaign.exitX >= playerX
                              ? Icons.arrow_forward
                              : Icons.arrow_back,
                          size: 16,
                        ),
                        Flexible(
                          child: Text(
                            context.l10n.campaignReachExit,
                            style: labelStyle,
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
