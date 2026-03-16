import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/board_manifest.dart';
import 'package:run_protocol/leaderboard_entry.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:run_protocol/submission_status.dart';
import 'package:run_protocol/run_ticket.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/pages/leaderboards/leaderboards_page.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/ghost_api.dart';
import 'package:rpg_runner/ui/state/ghost_replay_cache.dart';
import 'package:rpg_runner/ui/state/leaderboard_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/progression_state.dart';
import 'package:rpg_runner/ui/state/run_boards_api.dart';
import 'package:rpg_runner/ui/state/run_session_api.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:rpg_runner/ui/theme/ui_leaderboard_theme.dart';
import 'package:rpg_runner/ui/theme/ui_segmented_control_theme.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';

void main() {
  testWidgets('ghost start applies selection sync and navigates to run', (
    tester,
  ) async {
    final ownershipApi = _RecordingOwnershipApi();
    final appState = AppState(
      authApi: const _StaticAuthApi(),
      loadoutOwnershipApi: ownershipApi,
      runBoardsApi: const _StaticRunBoardsApi(),
      leaderboardApi: const _StaticLeaderboardApi(),
      runSessionApi: const _StaticRunSessionApi(),
      ghostApi: const _StaticGhostApi(),
      ghostReplayCache: const _StaticGhostReplayCache(),
    );
    await appState.bootstrap(force: true);

    await tester.pumpWidget(_TestApp(appState: appState));
    await tester.pumpAndSettle();

    await tester.tap(find.text('COMPETITIVE'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Race this ghost.').first);
    await tester.pumpAndSettle();

    expect(find.text('run-route-marker'), findsOneWidget);
    expect(ownershipApi.setSelectionCalls, 1);
    expect(appState.ownershipSyncStatus.pendingCount, 0);
    expect(appState.selection.selectedRunMode, RunMode.competitive);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: <ThemeExtension<dynamic>>[
            UiTokens.standard,
            UiSegmentedControlTheme.standard,
            UiLeaderboardTheme.standard,
          ],
        ),
        home: const LeaderboardsPage(),
        routes: <String, WidgetBuilder>{
          UiRoutes.run: (_) => const Scaffold(body: Text('run-route-marker')),
        },
      ),
    );
  }
}

class _StaticAuthApi implements AuthApi {
  const _StaticAuthApi();

  static const AuthSession _session = AuthSession(
    userId: 'u1',
    sessionId: 's1',
    isAnonymous: true,
    expiresAtMs: 0,
  );

  @override
  Future<AuthSession> ensureAuthenticatedSession() async => _session;

  @override
  Future<AuthSession> loadSession() async => _session;

  @override
  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    return AuthLinkResult(
      provider: provider,
      status: AuthLinkStatus.alreadyLinked,
      session: _session,
    );
  }

  @override
  Future<void> clearSession() async {}
}

class _RecordingOwnershipApi implements LoadoutOwnershipApi {
  int _revision = 0;
  int setSelectionCalls = 0;
  SelectionState _selection = SelectionState.defaults;
  final MetaService _metaService = const MetaService();

  OwnershipCanonicalState _canonical() {
    return OwnershipCanonicalState(
      profileId: 'test_profile',
      revision: _revision,
      selection: _selection,
      meta: _metaService.createNew(),
      progression: ProgressionState.initial,
    );
  }

  OwnershipCommandResult _acceptedResult() {
    _revision += 1;
    final canonical = _canonical();
    return OwnershipCommandResult(
      canonicalState: canonical,
      newRevision: canonical.revision,
      replayedFromIdempotency: false,
    );
  }

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    return _canonical();
  }

  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async {
    setSelectionCalls += 1;
    _selection = command.selection;
    return _acceptedResult();
  }

  @override
  Future<OwnershipCommandResult> resetOwnership(
    ResetOwnershipCommand command,
  ) async => _acceptedResult();

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async =>
      _acceptedResult();

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) async =>
      _acceptedResult();

  @override
  Future<OwnershipCommandResult> setAbilitySlot(
    SetAbilitySlotCommand command,
  ) async => _acceptedResult();

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) async => _acceptedResult();

  @override
  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  ) async => _acceptedResult();

  @override
  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  ) async => _acceptedResult();

  @override
  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command) async =>
      _acceptedResult();

  @override
  Future<OwnershipCommandResult> awardRunGold(
    AwardRunGoldCommand command,
  ) async => _acceptedResult();

  @override
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async => _acceptedResult();

  @override
  Future<OwnershipCommandResult> refreshStore(
    RefreshStoreCommand command,
  ) async => _acceptedResult();
}

class _StaticRunBoardsApi implements RunBoardsApi {
  const _StaticRunBoardsApi();

  @override
  Future<BoardManifest> loadActiveBoard({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) async {
    return BoardManifest(
      boardId: 'board_1',
      boardKey: BoardKey(
        mode: mode,
        levelId: levelId.name,
        windowId: '2026-03',
        rulesetVersion: 'rules-v1',
        scoreVersion: 'score-v1',
      ),
      gameCompatVersion: gameCompatVersion,
      ghostVersion: 'ghost-v1',
      tickHz: 60,
      seed: 7,
      opensAtMs: 1,
      closesAtMs: 999999999999,
      status: BoardStatus.active,
    );
  }
}

class _StaticLeaderboardApi implements LeaderboardApi {
  const _StaticLeaderboardApi();

  @override
  Future<OnlineLeaderboardBoard> loadBoard({
    required String userId,
    required String sessionId,
    required String boardId,
  }) async {
    return OnlineLeaderboardBoard(
      boardId: boardId,
      topEntries: <LeaderboardEntry>[
        LeaderboardEntry(
          boardId: boardId,
          entryId: 'entry_1',
          runSessionId: 'ghost_run_1',
          uid: 'u_top',
          displayName: 'Top Runner',
          characterId: 'eloise',
          score: 1234,
          distanceMeters: 456,
          durationSeconds: 89,
          sortKey: '0001:0001:0089:entry_1',
          ghostEligible: true,
          updatedAtMs: 1,
          rank: 1,
        ),
      ],
      updatedAtMs: 1,
    );
  }

  @override
  Future<OnlineLeaderboardMyRank> loadMyRank({
    required String userId,
    required String sessionId,
    required String boardId,
  }) async {
    return const OnlineLeaderboardMyRank(
      boardId: 'board_1',
      myEntry: null,
      rank: null,
      totalPlayers: 1,
    );
  }
}

class _StaticRunSessionApi implements RunSessionApi {
  const _StaticRunSessionApi();

  @override
  Future<RunTicket> createRunSession({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) async {
    return RunTicket(
      runSessionId: 'run_1',
      uid: userId,
      mode: mode,
      boardId: mode.requiresBoard ? 'board_1' : null,
      boardKey: mode.requiresBoard
          ? BoardKey(
              mode: mode,
              levelId: levelId.name,
              windowId: '2026-03',
              rulesetVersion: 'rules-v1',
              scoreVersion: 'score-v1',
            )
          : null,
      seed: 9,
      tickHz: 60,
      gameCompatVersion: gameCompatVersion,
      rulesetVersion: mode.requiresBoard ? 'rules-v1' : null,
      scoreVersion: mode.requiresBoard ? 'score-v1' : null,
      ghostVersion: mode.requiresBoard ? 'ghost-v1' : null,
      levelId: levelId.name,
      playerCharacterId: 'eloise',
      loadoutSnapshot: const <String, Object?>{},
      loadoutDigest: 'digest',
      issuedAtMs: 1,
      expiresAtMs: 999999999999,
      singleUseNonce: 'nonce',
    );
  }

  @override
  Future<RunUploadGrant> createUploadGrant({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SubmissionStatus> finalizeUpload({
    required String userId,
    required String sessionId,
    required String runSessionId,
    required String canonicalSha256,
    required int contentLengthBytes,
    String? contentType,
    String? objectPath,
    Map<String, Object?>? provisionalSummary,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SubmissionStatus> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) {
    throw UnimplementedError();
  }
}

class _StaticGhostApi implements GhostApi {
  const _StaticGhostApi();

  @override
  Future<GhostManifest> loadManifest({
    required String userId,
    required String sessionId,
    required String boardId,
    required String entryId,
  }) async {
    return GhostManifest(
      boardId: boardId,
      entryId: entryId,
      runSessionId: 'ghost_run_1',
      uid: 'u_top',
      replayStorageRef: 'ghosts/$boardId/$entryId/ghost.bin.gz',
      sourceReplayStorageRef: 'replays/source.bin.gz',
      downloadUrl: 'https://example.test/ghost.bin.gz',
      downloadUrlExpiresAtMs: 999999999999,
      score: 1234,
      distanceMeters: 456,
      durationSeconds: 89,
      sortKey: '0001:0001:0089:$entryId',
      rank: 1,
      updatedAtMs: 1,
    );
  }
}

class _StaticGhostReplayCache implements GhostReplayCache {
  const _StaticGhostReplayCache();

  @override
  Future<GhostReplayBootstrap> loadReplay({
    required GhostManifest manifest,
  }) async {
    final replayBlob = ReplayBlobV1.withComputedDigest(
      runSessionId: manifest.runSessionId,
      boardId: manifest.boardId,
      boardKey: const BoardKey(
        mode: RunMode.competitive,
        levelId: 'field',
        windowId: '2026-03',
        rulesetVersion: 'rules-v1',
        scoreVersion: 'score-v1',
      ),
      tickHz: 60,
      seed: 1,
      levelId: 'field',
      playerCharacterId: 'eloise',
      loadoutSnapshot: const <String, Object?>{},
      totalTicks: 0,
      commandStream: const <ReplayCommandFrameV1>[],
    );
    return GhostReplayBootstrap(
      manifest: manifest,
      replayBlob: replayBlob,
      cachedFile: File('ghost.replay.json'),
      cachedAtMs: 1,
    );
  }
}
