import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import '../../l10n/app_localization.dart';

/// Names and units only: eligibility, thresholds and rewards are server-owned.
enum AchievementPresentation {
  firstSteps(Icons.directions_walk),
  marathoner(Icons.flag_outlined),
  roadWarrior(Icons.route),
  stillStanding(Icons.hourglass_bottom),
  slayer(Icons.shield_outlined);

  const AchievementPresentation(this.icon);
  String title(AppLocalizations l10n) => switch (this) {
    firstSteps => l10n.achievementFirstSteps,
    marathoner => l10n.achievementMarathoner,
    roadWarrior => l10n.achievementRoadWarrior,
    stillStanding => l10n.achievementStillStanding,
    slayer => l10n.achievementSlayer,
  };
  final IconData icon;

  static AchievementPresentation? forId(String id) =>
      values.where((value) => value.name == id).firstOrNull;

  /// Only First Steps requires a qualifying completion; other metrics retain quits.
  String eligibility(AppLocalizations l10n) =>
      this == firstSteps ? l10n.achievementQualifying : l10n.achievementAllRuns;

  String quantity(int value, AppLocalizations l10n) => switch (this) {
    firstSteps => l10n.achievementRuns(count: value),
    marathoner || roadWarrior => l10n.achievementDistance(count: value),
    stillStanding => _duration(value, l10n),
    slayer => l10n.achievementEnemies(count: value),
  };
  String requirement(int target, AppLocalizations l10n) => switch (this) {
    firstSteps => l10n.achievementFinish(count: target),
    marathoner => l10n.achievementReach(count: target),
    roadWarrior => l10n.achievementTravel(count: target),
    stillStanding => l10n.achievementSurvive(duration: _duration(target, l10n)),
    slayer => l10n.achievementDefeat(count: target),
  };
}

String _duration(int seconds, AppLocalizations l10n) {
  final hours = seconds ~/ 3600;
  final minutes = seconds % 3600 ~/ 60;
  final remainder = seconds % 60;
  return [
    if (hours > 0) l10n.durationHours(count: hours),
    if (minutes > 0) l10n.durationMinutes(count: minutes),
    if (remainder > 0 || seconds == 0) l10n.durationSeconds(count: remainder),
  ].join(' ');
}

/// Uses the UTC calendar date without a visible timezone suffix. The host loads
/// locale date symbols; standalone callers initialize Intl date data.
String achievementDate(int milliseconds, AppLocalizations l10n) {
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  return DateFormat.yMMMd(l10n.localeName).format(date);
}
