import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/pages/achievements/achievement_presentation.dart';
import 'package:rpg_runner/ui/state/ownership/achievement_progress.dart';

import '../../support/achievement_fixtures.dart';

void main() {
  test(
    'decodes producer fixtures and preserves confirmation dates after claims',
    () {
      final empty = AchievementProgress.fromJson(achievementFixture('empty'));
      final earned = AchievementProgress.fromJson(achievementFixture('earned'));
      final claimed = AchievementProgress.fromJson(
        achievementFixture('claimed'),
      );
      expect(empty.entries.length, 5);
      expect(empty.hasRewards, isFalse);
      expect(earned.claimableGold, 175);
      expect(earned.entries[1].nextTier!.threshold, 2500);
      expect(claimed.hasRewards, isFalse);
      expect(
        claimed.entries[1].tiers.first.achievedAtMs,
        earned.entries[1].tiers.first.achievedAtMs,
      );
      expect(
        achievementDate(claimed.entries[1].tiers.first.achievedAtMs!),
        '30 Oct 2026 (UTC)',
      );
      expect(
        achievementDate(claimed.entries[1].tiers.first.claimedAtMs!),
        '31 Oct 2026 (UTC)',
      );
      expect(claimed.toJson(), achievementFixture('claimed'));
    },
  );
  test(
    'missing historical data is empty and parsed collections are detached',
    () {
      expect(AchievementProgress.fromJson(null).entries, isEmpty);
      final raw = achievementFixture('earned');
      final progress = AchievementProgress.fromJson(raw);
      (raw['entries'] as List).clear();
      expect(progress.entries.length, 5);
      expect(() => progress.entries.clear(), throwsUnsupportedError);
      expect(
        () => progress.entries.first.tiers.clear(),
        throwsUnsupportedError,
      );
    },
  );
  test(
    'rejects corrupted receipts, invalid numbers and unsupported schemas',
    () {
      for (final change in <void Function(Map<String, dynamic>)>[
        (raw) => raw['schemaVersion'] = 2,
        (raw) => raw['entries'][0]['value'] = -1,
        (raw) => raw['entries'][0]['value'] = 1.5,
        (raw) => raw['entries'][0]['tiers'][0]['claimedAtMs'] = 1,
        (raw) => raw['entries'][0]['tiers'][0]['achievedAtMs'] = null,
        (raw) =>
            raw['entries'][0]['tiers'][0]['achievedAtMs'] = 9007199254740991,
      ]) {
        final raw = achievementFixture('claimed');
        change(raw);
        expect(() => AchievementProgress.fromJson(raw), throwsFormatException);
      }
    },
  );
}
