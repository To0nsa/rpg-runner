import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/ownership/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/profile/account_deletion_api.dart';
import 'package:rpg_runner/ui/state/developer/developer_profile_store.dart';
import 'package:rpg_runner/ui/state/run/run_submission_spool_store.dart';

import '../../support/achievement_fixtures.dart';

void main() {
  test(
    'Developer Practice cannot refresh or claim remote achievements',
    () async {
      final app = AppState.developer(store: _UnusedDeveloperStore());
      addTearDown(app.dispose);
      expect(app.achievementsAvailable, isFalse);
      await app.refreshAchievements();
      await app.claimAchievements();
      expect(app.progression.achievements.entries, isEmpty);
    },
  );
  test(
    'accepted account deletion fences late claim replies and further requests',
    () async {
      final api = AchievementTestApi(achievementCanonical('earned'));
      final app = AppState(
        authApi: AchievementTestAuth(),
        loadoutOwnershipApi: api,
        accountDeletionApi: _AcceptedDeletionApi(),
        runSubmissionSpoolStore: _EmptySpool(),
      );
      addTearDown(app.dispose);
      await app.bootstrap(force: true);
      final response = Completer<OwnershipCommandResult>();
      api.onClaim = (_) => response.future;
      final claim = app.claimAchievements();
      await Future<void>.delayed(Duration.zero);
      expect((await app.deleteAccountAndData()).succeeded, isTrue);
      response.complete(
        achievementResult(
          achievementCanonical('claimed', revision: 2, gold: 175),
        ),
      );
      await claim;
      await app.claimAchievements();
      expect(app.achievementsAvailable, isFalse);
      expect(app.progression.gold, 0);
      expect(app.progression.achievements.entries, isEmpty);
      expect(api.claims.length, 1);
    },
  );
  test(
    'coalesces taps without optimistic gold; failed responses remain retryable',
    () async {
      final api = AchievementTestApi(achievementCanonical('earned'));
      final app = AppState(
        authApi: AchievementTestAuth(),
        loadoutOwnershipApi: api,
      );
      addTearDown(app.dispose);
      await app.bootstrap(force: true);
      var response = Completer<OwnershipCommandResult>();
      api.onClaim = (_) => response.future;
      final pending = app.claimAchievements();
      await Future<void>.delayed(Duration.zero);
      await app.claimAchievements();
      expect(api.claims.length, 1);
      expect(app.achievementsClaiming, isTrue);
      expect(app.progression.gold, 0);
      response.completeError(StateError('connection lost'));
      await expectLater(pending, throwsStateError);
      expect(app.achievementsClaiming, isFalse);
      expect(app.progression.achievements.claimableGold, 175);
      response = Completer<OwnershipCommandResult>();
      final retry = app.claimAchievements();
      await Future<void>.delayed(Duration.zero);
      expect(api.claims.last.commandId, isNot(api.claims.first.commandId));
      response.complete(
        achievementResult(
          achievementCanonical('claimed', revision: 2, gold: 175),
        ),
      );
      await retry;
      expect(app.progression.gold, 175);
      expect(app.progression.achievements.hasRewards, isFalse);
    },
  );
  test(
    'retries a stale revision once with fresh identity and canonical revision',
    () async {
      final api = AchievementTestApi(achievementCanonical('earned'));
      final app = AppState(
        authApi: AchievementTestAuth(),
        loadoutOwnershipApi: api,
      );
      addTearDown(app.dispose);
      await app.bootstrap(force: true);
      api.onClaim = (_) async => api.claims.length == 1
          ? achievementResult(
              achievementCanonical('earned', revision: 2),
              rejectedReason: OwnershipRejectedReason.staleRevision,
            )
          : achievementResult(
              achievementCanonical('claimed', revision: 3, gold: 175),
            );
      await app.claimAchievements(achievementId: 'marathoner');
      expect(api.claims.map((c) => c.expectedRevision), [1, 2]);
      expect(api.claims.map((c) => c.commandId).toSet().length, 2);
      expect(api.claims.last.payloadToJson(), {'achievementId': 'marathoner'});
      expect(app.progression.gold, 175);
    },
  );
  test('late refresh cannot regress a successful claim', () async {
    final api = AchievementTestApi(achievementCanonical('earned'));
    final app = AppState(
      authApi: AchievementTestAuth(),
      loadoutOwnershipApi: api,
    );
    addTearDown(app.dispose);
    await app.bootstrap(force: true);
    final response = Completer<OwnershipCanonicalState>();
    api.onLoad = () => response.future;
    final refresh = app.refreshAchievements();
    await Future<void>.delayed(Duration.zero);
    api.onClaim = (_) async => achievementResult(
      achievementCanonical('claimed', revision: 2, gold: 175),
    );
    await app.claimAchievements();
    response.complete(achievementCanonical('earned'));
    await refresh;
    expect(app.progression.gold, 175);
    expect(app.progression.achievements.hasRewards, isFalse);
  });
  test('late claim cannot overwrite a replacement account', () async {
    final auth = AchievementTestAuth();
    final api = AchievementTestApi(achievementCanonical('earned'));
    final app = AppState(authApi: auth, loadoutOwnershipApi: api);
    addTearDown(app.dispose);
    await app.bootstrap(force: true);
    final response = Completer<OwnershipCommandResult>();
    api.onClaim = (_) => response.future;
    final claim = app.claimAchievements();
    await Future<void>.delayed(Duration.zero);
    auth.session = auth.session.copyWith(userId: 'replacement');
    api.canonical = achievementCanonical('empty', gold: 7);
    await app.bootstrap(force: true);
    response.complete(
      achievementResult(
        achievementCanonical('claimed', revision: 10, gold: 175),
      ),
    );
    await claim;
    expect(app.authSession.userId, 'replacement');
    expect(app.progression.gold, 7);
    expect(app.progression.achievements.hasRewards, isFalse);
  });
  test('disposed app ignores a late claim', () async {
    final api = AchievementTestApi(achievementCanonical('earned'));
    final app = AppState(
      authApi: AchievementTestAuth(),
      loadoutOwnershipApi: api,
    );
    await app.bootstrap(force: true);
    final response = Completer<OwnershipCommandResult>();
    api.onClaim = (_) => response.future;
    final claim = app.claimAchievements();
    await Future<void>.delayed(Duration.zero);
    app.dispose();
    response.complete(
      achievementResult(
        achievementCanonical('claimed', revision: 2, gold: 175),
      ),
    );
    await claim;
    expect(app.progression.gold, 0);
  });
}

class _AcceptedDeletionApi implements AccountDeletionApi {
  @override
  Future<AccountDeletionResult> deleteAccountAndData({
    required String userId,
    required String sessionId,
  }) async =>
      const AccountDeletionResult(status: AccountDeletionStatus.requested);
}

class _UnusedDeveloperStore extends Fake implements DeveloperProfileStore {}

class _EmptySpool extends Fake implements RunSubmissionSpoolStore {
  @override
  Future<void> clear() async {}
}
