import 'package:runner_core/commands/command.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/scoring/run_score_breakdown.dart';
import 'package:test/test.dart';

String _snapshotDigest(GameCore core) {
  final s = core.buildSnapshot();
  final parts = <String>[
    't=${s.tick}',
    'dist=${s.distance.toStringAsFixed(6)}',
    'camx=${s.camera.centerX.toStringAsFixed(6)}',
    'camy=${s.camera.centerY.toStringAsFixed(6)}',
    'level=${s.levelId.name}',
    'theme=${s.visualThemeId}',
    'hp=${s.hud.hp.toStringAsFixed(6)}',
    'mana=${s.hud.mana.toStringAsFixed(6)}',
    'stamina=${s.hud.stamina.toStringAsFixed(6)}',
    'collectibles=${s.hud.collectibles}',
    'collectibleScore=${s.hud.collectibleScore}',
    'solids=${s.staticSolids.length}',
    'groundSurfaces=${s.groundSurfaces.length}',
    'ents=${s.entities.length}',
    'paused=${s.paused}',
    'gameOver=${s.gameOver}',
  ];

  for (final e in s.entities) {
    parts.addAll([
      'id=${e.id}',
      'k=${e.kind.name}',
      'px=${e.pos.x.toStringAsFixed(6)}',
      'py=${e.pos.y.toStringAsFixed(6)}',
      if (e.vel != null) 'vx=${e.vel!.x.toStringAsFixed(6)}',
      if (e.vel != null) 'vy=${e.vel!.y.toStringAsFixed(6)}',
      if (e.size != null) 'sx=${e.size!.x.toStringAsFixed(6)}',
      if (e.size != null) 'sy=${e.size!.y.toStringAsFixed(6)}',
      if (e.projectileId != null) 'pid=${e.projectileId!.name}',
      'rot=${e.rotationRad.toStringAsFixed(6)}',
      'f=${e.facing.name}',
      'a=${e.anim.name}',
      'g=${e.grounded}',
    ]);
  }

  return parts.join('|');
}

RunEndedEvent _finalizeAndGetRunEnded(GameCore core) {
  if (!core.gameOver) {
    core.giveUp();
  }
  final events = core.drainEvents();
  final runEndedEvents = events.whereType<RunEndedEvent>().toList();
  expect(runEndedEvents, isNotEmpty);
  return runEndedEvents.last;
}

void _runDeterminismScenario({
  required int seed,
  required LevelDefinition level,
  required PlayerCharacterDefinition playerCharacter,
}) {
  final a = GameCore(
    seed: seed,
    levelDefinition: level,
    playerCharacter: playerCharacter,
  );
  final b = GameCore(
    seed: seed,
    levelDefinition: level,
    playerCharacter: playerCharacter,
  );

  const ticks = 240;
  for (var t = 1; t <= ticks; t += 1) {
    if (a.gameOver || b.gameOver) break;
    final cmds = <Command>[];

    final axis = (t <= 120) ? 1.0 : -1.0;
    cmds.add(MoveAxisCommand(tick: t, axis: axis));

    if (t == 10) cmds.add(const JumpPressedCommand(tick: 10));
    if (t == 60) cmds.add(const DashPressedCommand(tick: 60));
    if (t == 90) cmds.add(const StrikePressedCommand(tick: 90));
    if (t == 140) cmds.add(const ProjectilePressedCommand(tick: 140));

    a.applyCommands(cmds);
    a.stepOneTick();
    b.applyCommands(cmds);
    b.stepOneTick();

    expect(_snapshotDigest(a), _snapshotDigest(b));
  }

  final endA = _finalizeAndGetRunEnded(a);
  final endB = _finalizeAndGetRunEnded(b);

  expect(endA.tick, endB.tick);
  expect(endA.distance, closeTo(endB.distance, 1e-9));
  expect(endA.stats.collectibles, endB.stats.collectibles);
  expect(endA.stats.collectibleScore, endB.stats.collectibleScore);
  expect(endA.stats.enemyKillCounts, endB.stats.enemyKillCounts);

  final scoreA = buildRunScoreBreakdown(
    tick: endA.tick,
    distanceUnits: endA.distance,
    collectibles: endA.stats.collectibles,
    collectibleScore: endA.stats.collectibleScore,
    enemyKillCounts: endA.stats.enemyKillCounts,
    tuning: a.scoreTuning,
    tickHz: a.tickHz,
  );
  final scoreB = buildRunScoreBreakdown(
    tick: endB.tick,
    distanceUnits: endB.distance,
    collectibles: endB.stats.collectibles,
    collectibleScore: endB.stats.collectibleScore,
    enemyKillCounts: endB.stats.enemyKillCounts,
    tuning: b.scoreTuning,
    tickHz: b.tickHz,
  );

  expect(scoreA.totalPoints, scoreB.totalPoints);
  expect(scoreA.rows.length, scoreB.rows.length);
  for (var i = 0; i < scoreA.rows.length; i += 1) {
    final rowA = scoreA.rows[i];
    final rowB = scoreB.rows[i];
    expect(rowA.kind, rowB.kind);
    expect(rowA.count, rowB.count);
    expect(rowA.points, rowB.points);
    expect(rowA.enemyId, rowB.enemyId);
  }
}

void main() {
  final playerCharacter = PlayerCharacterRegistry.resolve(
    PlayerCharacterId.eloise,
  );

  test('same seed + same commands => deterministic snapshots (field)', () {
    _runDeterminismScenario(
      seed: 42,
      level: LevelRegistry.byId(LevelId.field),
      playerCharacter: playerCharacter,
    );
  });

  test('same seed + same commands => stable score/distance/duration/tick (forest)', () {
    _runDeterminismScenario(
      seed: 42,
      level: LevelRegistry.byId(LevelId.forest),
      playerCharacter: playerCharacter,
    );
  });
}
