import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:rpg_runner/ui/codex/codex_catalog.dart';
import 'package:rpg_runner/ui/state/ownership/codex_progress.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';

void main() {
  test('legacy accounts start empty; wallet updates preserve discoveries', () {
    expect(ProgressionState.fromJson({'gold': 15}).codex.enemyKills, isEmpty);
    final kills = {'grojib': 10};
    final codex = CodexProgress(
      enemyKills: kills,
      competitiveBestScores: {'forest': 10000},
    );
    kills['grojib'] = 0;
    final state = ProgressionState.initial.copyWith(codex: codex);
    final decoded = ProgressionState.fromJson(state.toJson())
        .copyWith(gold: 42);
    expect(decoded.codex.enemyKills, {'grojib': 10});
    expect(decoded.codex.competitiveBestScores, {'forest': 10000});
    expect(
      () => decoded.codex.enemyKills['grojib'] = 0,
      throwsUnsupportedError,
    );
    (codex.toJson()['enemyKills']! as Map)['grojib'] = 0;
    expect(codex.enemyKills['grojib'], 10);
  });

  test('each enemy and boss unlocks at its own exact kill threshold', () {
    for (final id in CodexCatalog.bestiaryEntries) {
      final threshold = id.isBoss ? 5 : 10;
      expect(
        CodexCatalog.enemyUnlocked(
          CodexProgress(enemyKills: {id.name: threshold - 1}),
          id,
        ),
        isFalse,
      );
      final progress = CodexProgress(enemyKills: {id.name: threshold});
      expect(CodexCatalog.enemyUnlocked(progress, id), isTrue);
      for (final other in CodexCatalog.bestiaryEntries.where(
        (other) => other != id,
      )) {
        expect(CodexCatalog.enemyUnlocked(progress, other), isFalse);
      }
      expect(CodexCatalog.attacks(id), isNotEmpty);
      expect(CodexCatalog.enemyLore(id), isNotEmpty);
    }
  });

  test('summons belong to their boss and share its discovery gate', () {
    expect(CodexCatalog.bestiaryEntries, hasLength(8));
    for (final pair in {
      EnemyId.shoggoth: EnemyId.shoggothMinion,
      EnemyId.voidcaller: EnemyId.voidTentacle,
    }.entries) {
      expect(CodexCatalog.summonsFor(pair.key), [pair.value]);
      expect(
        CodexCatalog.enemyUnlocked(
          CodexProgress(enemyKills: {pair.value.name: 100}),
          pair.value,
        ),
        isFalse,
      );
      expect(
        CodexCatalog.enemyUnlocked(
          CodexProgress(enemyKills: {pair.key.name: 4}),
          pair.value,
        ),
        isFalse,
      );
      expect(
        CodexCatalog.enemyUnlocked(
          CodexProgress(enemyKills: {pair.key.name: 5}),
          pair.value,
        ),
        isTrue,
      );
    }
  });

  test('Forest and Field each need 10000; unpublished levels stay locked', () {
    expect(CodexCatalog.levelScoreRequirements.keys, [
      LevelId.forest,
      LevelId.field,
    ]);
    for (final id in CodexCatalog.levelScoreRequirements.keys) {
      expect(
        CodexCatalog.levelUnlocked(
          CodexProgress(competitiveBestScores: {id.name: 9999}),
          id,
        ),
        isFalse,
      );
      final progress = CodexProgress(competitiveBestScores: {id.name: 10000});
      expect(CodexCatalog.levelUnlocked(progress, id), isTrue);
      for (final other in LevelId.values.where((other) => other != id)) {
        expect(CodexCatalog.levelUnlocked(progress, other), isFalse);
      }
    }
  });

  test('malformed remote progress fails rather than granting discoveries', () {
    for (final count in [-1, 1.5, double.infinity, 9007199254740992, '10']) {
      expect(
        () => CodexProgress.fromJson({
          'schemaVersion': 1,
          'enemyKills': {'grojib': count},
          'competitiveBestScores': {},
        }),
        throwsFormatException,
      );
    }
    expect(
      () => CodexProgress.fromJson({'schemaVersion': 2}),
      throwsFormatException,
    );
  });
}
