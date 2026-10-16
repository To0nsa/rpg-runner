import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:rpg_runner/ui/codex/codex_catalog.dart';
import 'package:rpg_runner/ui/state/ownership/codex_progress.dart';
import 'package:rpg_runner/ui/state/ownership/enemy_defeats.dart';
import 'package:rpg_runner/ui/state/ownership/player_progress.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';

void main() {
  test('shared defeats are detached and survive wallet updates', () {
    expect(
      ProgressionState.fromJson({'gold': 15}).enemyDefeats.byEnemy,
      isEmpty,
    );
    final kills = {'grojib': 10};
    final defeats = EnemyDefeats(byEnemy: kills);
    final state = ProgressionState.initial.copyWith(
      enemyDefeats: defeats,
      codex: CodexProgress(competitiveBestScores: {'forest': 10000}),
      playerProgress: const PlayerProgress(
        totalXp: 100,
        acceptedRuns: 1,
        damageDealt100: 200,
        damageTaken100: 50,
      ),
    );
    kills['grojib'] = 0;
    final decoded = ProgressionState.fromJson(state.toJson())
        .copyWith(gold: 42);
    expect(decoded.enemyDefeats.byEnemy, {'grojib': 10});
    expect(decoded.enemyDefeats.total, 10);
    expect(decoded.codex.competitiveBestScores, {'forest': 10000});
    expect(decoded.playerProgress.totalXp, 100);
    expect(
      () => decoded.enemyDefeats.byEnemy['grojib'] = 0,
      throwsUnsupportedError,
    );
    (defeats.toJson()['byEnemy']! as Map)['grojib'] = 0;
    expect(defeats.byEnemy['grojib'], 10);
  });

  test('old Codex kills project to shared defeats until settlement', () {
    final legacy = <String, Object?>{
      'gold': 0,
      'codex': {
        'schemaVersion': 1,
        'enemyKills': {'grojib': 10},
        'competitiveBestScores': {'forest': 10000},
      },
    };
    final projected = ProgressionState.fromJson(legacy);
    expect(projected.enemyDefeats.byEnemy, {'grojib': 10});
    expect(projected.codex.competitiveBestScores, {'forest': 10000});
    expect(
      ProgressionState.fromJson(projected.toJson()).enemyDefeats.total,
      10,
    );

    legacy['enemyDefeats'] = {
      'schemaVersion': 1,
      'byEnemy': {'grojib': 12},
    };
    expect(ProgressionState.fromJson(legacy).enemyDefeats.total, 12);
  });

  test('each enemy and boss unlocks at its exact defeat threshold', () {
    for (final id in CodexCatalog.bestiaryEntries) {
      final threshold = id.isBoss ? 5 : 10;
      expect(
        CodexCatalog.enemyUnlocked(
          EnemyDefeats(byEnemy: {id.name: threshold - 1}),
          id,
        ),
        isFalse,
      );
      final defeats = EnemyDefeats(byEnemy: {id.name: threshold});
      expect(CodexCatalog.enemyUnlocked(defeats, id), isTrue);
      for (final other in CodexCatalog.bestiaryEntries.where(
        (other) => other != id,
      )) {
        expect(CodexCatalog.enemyUnlocked(defeats, other), isFalse);
      }
      expect(CodexCatalog.attacks(id), isNotEmpty);
      expect(CodexCatalog.enemyLore(id), isNotEmpty);
    }
  });

  test('summons share their boss discovery gate', () {
    expect(CodexCatalog.bestiaryEntries, hasLength(8));
    for (final pair in {
      EnemyId.shoggoth: EnemyId.shoggothMinion,
      EnemyId.voidcaller: EnemyId.voidTentacle,
    }.entries) {
      expect(CodexCatalog.summonsFor(pair.key), [pair.value]);
      expect(
        CodexCatalog.enemyUnlocked(
          EnemyDefeats(byEnemy: {pair.value.name: 100}),
          pair.value,
        ),
        isFalse,
      );
      expect(
        CodexCatalog.enemyUnlocked(
          EnemyDefeats(byEnemy: {pair.key.name: 4}),
          pair.value,
        ),
        isFalse,
      );
      expect(
        CodexCatalog.enemyUnlocked(
          EnemyDefeats(byEnemy: {pair.key.name: 5}),
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

  test(
    'malformed remote defeat counts fail rather than granting discoveries',
    () {
      for (final count in [-1, 1.5, double.infinity, 9007199254740992, '10']) {
        expect(
          () => EnemyDefeats.fromJson({
            'schemaVersion': 1,
            'byEnemy': {'grojib': count},
          }),
          throwsFormatException,
        );
        expect(
          () => ProgressionState.fromJson({
            'codex': {
              'schemaVersion': 1,
              'enemyKills': {'grojib': count},
              'competitiveBestScores': {},
            },
          }),
          throwsFormatException,
        );
      }
      expect(
        () => CodexProgress.fromJson({'schemaVersion': 3}),
        throwsFormatException,
      );
    },
  );
}
