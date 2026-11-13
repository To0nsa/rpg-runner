import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/tuning/score_tuning.dart';
import 'package:rpg_runner/game/replay/run_recorder.dart';
import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/run/run_replay_finalization.dart';
import 'package:rpg_runner/ui/run/runner_run_session.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';
import 'package:rpg_runner/ui/state/run/run_submission_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'retired attempt finishes under its own ID before recorder closes',
    () async {
      final recorder = _Recorder();
      final journal = _Journal();
      final old = RunnerRunSession(
        descriptor: _descriptor,
        createRecorder: (_) async => recorder,
      );
      await Future<void>.delayed(Duration.zero);
      var notifications = 0;
      old.finalization.addListener(() => notifications++);
      final operation = old.finalization.complete(
        _event,
        recorder: recorder,
        journal: journal.write,
      );
      expect(
        identical(
          operation,
          old.finalization.complete(
            _event,
            recorder: recorder,
            journal: journal.write,
          ),
        ),
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);
      final stopped = old.stop();
      old.dispose();
      final countAtDisposal = notifications;
      final replacement = RunReplayFinalization(
        descriptor: _descriptor,
        scoreTuning: const ScoreTuning(),
      );
      addTearDown(replacement.dispose);
      expect(recorder.closes, 0);
      recorder.pending.complete(_artifact);
      await operation;
      await stopped;
      expect(journal.ids, ['old-attempt']);
      expect(journal.summaries.single['runId'], 12);
      expect(recorder.finalizes, 1);
      expect(recorder.closes, 1);
      expect(notifications, countAtDisposal);
      expect(replacement.journaled, isFalse);
      expect(replacement.status, isNull);
    },
  );

  test(
    'failed journal can retry, duplicate completion cannot resubmit',
    () async {
      final recorder = _Recorder()..pending.complete(_artifact);
      final journal = _Journal()..fail = true;
      final attempt = RunReplayFinalization(
        descriptor: _descriptor,
        scoreTuning: const ScoreTuning(),
      );
      addTearDown(attempt.dispose);
      await attempt.complete(
        _event,
        recorder: recorder,
        journal: journal.write,
      );
      expect(attempt.journaled, isFalse);
      expect(attempt.error, isNotNull);
      await attempt.complete(
        _event,
        recorder: recorder,
        journal: journal.write,
      );
      expect(journal.ids, hasLength(1));
      journal.fail = false;
      await attempt.retry(recorder: recorder, journal: journal.write);
      await attempt.retry(recorder: recorder, journal: journal.write);
      expect(attempt.journaled, isTrue);
      expect(journal.ids, hasLength(2));
      expect(attempt.error, isNull);
    },
  );
}

const _descriptor = RunStartDescriptor(
  runSessionId: 'old-attempt',
  runId: 12,
  seed: 42,
  tickHz: 60,
  levelId: LevelId.field,
  playerCharacterId: PlayerCharacterId.eloise,
  runMode: RunMode.practice,
  equippedLoadout: EquippedLoadoutDef(),
);
const _event = RunEndedEvent(
  runId: 12,
  tick: 120,
  distance: 200,
  reason: RunEndReason.gaveUp,
  stats: RunEndStats(
    collectibles: 0,
    collectibleScore: 0,
    enemyKillCounts: [0, 0],
  ),
  goldEarned: 2,
);
final _artifact = RunRecorderFinalizeResult(
  replayBlob: ReplayBlobV1(
    runSessionId: 'old-attempt',
    tickHz: 60,
    seed: 42,
    levelId: 'field',
    playerCharacterId: 'eloise',
    loadoutSnapshot: {},
    totalTicks: 120,
    commandStream: [],
    canonicalSha256: 'a' * 64,
  ),
  replayArtifactId: 'old-artifact',
  contentLengthBytes: 128,
  streamDigestSha256: 'b' * 64,
  framesRecorded: 0,
);

class _Recorder implements RunRecorder {
  final pending = Completer<RunRecorderFinalizeResult>();
  int finalizes = 0;
  int closes = 0;
  @override
  Future<RunRecorderFinalizeResult> finalize({
    Map<String, Object?>? clientSummary,
  }) {
    finalizes++;
    return pending.future;
  }

  @override
  Future<void> close() async {
    closes++;
  }

  @override
  void appendFrame(ReplayCommandFrameV1 frame) {}
}

class _Journal {
  bool fail = false;
  final ids = <String>[];
  final summaries = <Map<String, Object?>>[];
  Future<RunSubmissionStatus> write({
    required String runSessionId,
    required RunMode runMode,
    required String replayArtifactId,
    required String canonicalSha256,
    required int contentLengthBytes,
    Map<String, Object?>? provisionalSummary,
  }) async {
    ids.add(runSessionId);
    summaries.add(provisionalSummary!);
    if (fail) throw StateError('storage unavailable');
    return RunSubmissionStatus(
      runSessionId: runSessionId,
      phase: RunSubmissionPhase.queued,
      updatedAtMs: 0,
    );
  }
}
