import 'package:flutter/material.dart';

import '../../text/number_format.dart';

/// Names and units only: eligibility, thresholds and rewards are server-owned.
enum AchievementPresentation {
  firstSteps('First Steps', Icons.directions_walk),
  marathoner('Marathoner', Icons.flag_outlined),
  roadWarrior('Road Warrior', Icons.route),
  stillStanding('Still Standing', Icons.hourglass_bottom),
  slayer('Slayer', Icons.shield_outlined);

  const AchievementPresentation(this.title, this.icon);
  final String title;
  final IconData icon;

  static AchievementPresentation? forId(String id) =>
      values.where((value) => value.name == id).firstOrNull;

  String quantity(int value) => switch (this) {
    firstSteps => '${formatCount(value)} ${value == 1 ? 'run' : 'runs'}',
    marathoner || roadWarrior => '${formatCount(value)} m',
    stillStanding => _duration(value),
    slayer => '${formatCount(value)} enemies',
  };

  String requirement(int target) => switch (this) {
    firstSteps =>
      'Finish ${formatCount(target)} qualifying ${target == 1 ? 'run' : 'runs'}.',
    marathoner => 'Reach ${formatCount(target)} metres in one run.',
    roadWarrior => 'Travel ${formatCount(target)} metres across runs.',
    stillStanding => 'Survive ${_duration(target)} across runs.',
    slayer => 'Defeat ${formatCount(target)} enemies across runs.',
  };
}

String _duration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = seconds % 3600 ~/ 60;
  final remainder = seconds % 60;
  return [
    if (hours > 0) '${hours}h',
    if (minutes > 0) '${minutes}m',
    if (remainder > 0 || seconds == 0) '${remainder}s',
  ].join(' ');
}

/// UTC dates remain identical across devices and never use the claim time.
String achievementDate(int milliseconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year} (UTC)';
}
