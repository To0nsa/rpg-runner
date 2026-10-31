import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:run_protocol/submission_status.dart';
import 'package:rpg_runner/ui/app/ui_router.dart';
import 'package:rpg_runner/ui/components/attention_marker.dart';
import 'package:rpg_runner/ui/pages/achievements/achievement_claim_action.dart';
import 'package:rpg_runner/ui/pages/town/town_map.dart';
import 'package:rpg_runner/ui/pages/achievements/achievements_page.dart';
import 'package:rpg_runner/ui/pages/town/town_page.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/ownership/achievement_progress.dart';
import 'package:rpg_runner/ui/state/ownership/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/run/pending_run_submission.dart';
import 'package:rpg_runner/ui/state/run/run_session_api.dart';
import 'package:rpg_runner/ui/state/run/run_submission_spool_store.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';

import '../../../support/achievement_fixtures.dart';

const _capture = bool.fromEnvironment('CAPTURE_ACHIEVEMENTS');
final _boundary = GlobalKey();

void main() {
  testWidgets('verified progress updates the open hall without a refresh tap', (
    tester,
  ) async {
    final api = AchievementTestApi(achievementCanonical('empty'));
    var ownershipReads = 0;
    api.onLoad = () async {
      ownershipReads += 1;
      return api.canonical;
    };
    final source = _TestCompletionSource();
    final app = AppState(
      authApi: AchievementTestAuth(),
      loadoutOwnershipApi: api,
      runSessionApi: _PendingRunSessionApi(),
      runCompletionSource: source,
      runSubmissionSpoolStore: _EmptySpool(),
    );
    addTearDown(() async {
      app.dispose();
      await source.controller.close();
    });
    await app.bootstrap();
    await tester.pumpWidget(_host(app));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Refresh achievements'), findsNothing);
    expect(find.byType(AchievementClaimAction), findsNothing);
    expect(find.text('0 runs / 1 run'), findsOneWidget);
    await tester.tap(find.text('First Steps'));
    await tester.pumpAndSettle();
    final readsBeforeCompletion = ownershipReads;

    app.setRunSubmissionForeground(true);
    await app.refreshRunSubmissionStatus(runSessionId: 'achievement_run');
    expect(source.controller.hasListener, isTrue);
    expect(app.progression.achievements.hasRewards, isFalse);
    source.controller.add(
      RunSubmissionResponse(
        SubmissionStatus(
          runSessionId: 'achievement_run',
          state: RunSessionState.validated,
          updatedAtMs: 2000,
          reward: SubmissionReward(
            status: SubmissionRewardStatus.finalReward,
            provisionalGold: 0,
            effectiveGoldDelta: 0,
            spendableGoldDelta: 0,
            updatedAtMs: 2000,
            grantId: 'achievement_run',
          ),
        ),
        canonical: achievementCanonical('earned', revision: 2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 run / 10 runs'), findsOneWidget);
    expect(find.text('Claim all'), findsOneWidget);
    expect(find.byKey(const ValueKey('claim-firstSteps')), findsOneWidget);
    expect(find.text('Bronze'), findsOneWidget);
    expect(find.text('Achieved 30 Oct 2026 (UTC)'), findsOneWidget);
    expect(app.progression.gold, 0);
    expect(app.latestVerifiedReward?.runSessionId, 'achievement_run');
    expect(ownershipReads, readsBeforeCompletion);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded history is scoped to the current account', (
    tester,
  ) async {
    final auth = AchievementTestAuth();
    final api = AchievementTestApi(achievementCanonical('earned'));
    final app = AppState(authApi: auth, loadoutOwnershipApi: api);
    addTearDown(app.dispose);
    await app.bootstrap(force: true);
    await tester.pumpWidget(_host(app));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First Steps'));
    await tester.pumpAndSettle();
    expect(find.text('Bronze'), findsOneWidget);
    auth.session = auth.session.copyWith(userId: 'replacement');
    api.canonical = achievementCanonical('empty');
    await app.bootstrap(force: true);
    await tester.pumpAndSettle();
    expect(find.text('Bronze'), findsNothing);
    expect(find.textContaining('Achieved '), findsNothing);
    expect(find.byType(AchievementClaimAction), findsNothing);
  });
  testWidgets(
    'collapsed rows show only next tier; expansion shows full dated history',
    (tester) async {
      final app = await _boot();
      addTearDown(app.dispose);
      await tester.pumpWidget(_host(app));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('achievement-marathoner'));
      expect(
        find.descendant(
          of: row,
          matching: find.text('Reach 2,500 metres in one run.'),
        ),
        findsOneWidget,
      );
      expect(find.text('Bronze'), findsNothing);
      expect(find.text('Reach 500 metres in one run.'), findsNothing);
      expect(find.byKey(const ValueKey('claim-marathoner')), findsOneWidget);
      await tester.ensureVisible(row);
      await tester.tap(find.text('Marathoner'));
      await tester.pumpAndSettle();
      expect(find.text('Bronze'), findsOneWidget);
      expect(find.text('Silver'), findsOneWidget);
      expect(find.text('Gold'), findsOneWidget);
      expect(find.text('Reach 500 metres in one run.'), findsOneWidget);
      expect(find.text('Achieved 30 Oct 2026 (UTC)'), findsNWidgets(2));
      expect(find.textContaining('10 metres or 10 seconds'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('claim all waits for canonical gold and removes claim actions', (
    tester,
  ) async {
    final api = AchievementTestApi(achievementCanonical('earned'));
    final app = await _boot(api: api);
    addTearDown(app.dispose);
    final response = Completer<OwnershipCommandResult>();
    api.onClaim = (_) => response.future;
    await tester.pumpWidget(_host(app));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claim all'));
    await tester.pump();
    expect(
      tester
          .widget<AchievementClaimAction>(
            find.byKey(const ValueKey('claim-marathoner')),
          )
          .onPressed,
      isNull,
    );
    expect(api.claims.length, 1);
    expect(app.progression.gold, 0);
    response.complete(
      achievementResult(
        achievementCanonical('claimed', revision: 2, gold: 175),
      ),
    );
    await tester.pumpAndSettle();
    expect(app.progression.gold, 175);
    expect(find.byType(AchievementClaimAction), findsNothing);
    await tester.tap(find.text('Marathoner'));
    await tester.pumpAndSettle();
    expect(find.text('25 gold · Claimed'), findsOneWidget);
    expect(find.text('75 gold · Claimed'), findsOneWidget);
    expect(find.text('Achieved 30 Oct 2026 (UTC)'), findsNWidgets(2));
  });
  testWidgets('final tier stays claimable until its reward is collected', (
    tester,
  ) async {
    final raw = achievementFixture('earned');
    final entry = raw['entries'][1];
    entry['value'] = 2500;
    entry['tiers'][2]['achievedAtMs'] = entry['tiers'][0]['achievedAtMs'];
    final base = achievementCanonical('earned');
    final api = AchievementTestApi(
      base.copyWith(
        progression: base.progression.copyWith(
          achievements: AchievementProgress.fromJson(raw),
        ),
      ),
    );
    final app = await _boot(api: api);
    addTearDown(app.dispose);
    api.onClaim = (command) async {
      for (final tier in entry['tiers']) {
        tier['claimedAtMs'] = tier['achievedAtMs'];
      }
      return achievementResult(
        api.canonical.copyWith(
          revision: 2,
          progression: api.canonical.progression.copyWith(
            gold: 250,
            achievements: AchievementProgress.fromJson(raw),
          ),
        ),
      );
    };
    await tester.pumpWidget(_host(app));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.byKey(const ValueKey('claim-marathoner')), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('claim-marathoner')),
        matching: find.text('Claim'),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.claims.single.achievementId, 'marathoner');
    expect(find.text('Completed'), findsOneWidget);
    expect(find.byKey(const ValueKey('claim-marathoner')), findsNothing);
    expect(find.text('Bronze'), findsNothing); // Claim did not expand the row.
  });
  for (final size in [const Size(640, 360), const Size(360, 640)]) {
    testWidgets('town link, attention and expanded layout work at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (_capture) await _fonts();
      final app = await _boot();
      addTearDown(app.dispose);
      await tester.pumpWidget(
        _host(app, home: const TownPage(), textScale: 1.4),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((w) => w is AttentionMarker && w.visible),
        findsOneWidget,
      );
      await _screenshot(tester, 'town-${size.width.toInt()}');
      final marker = find.byKey(const ValueKey('town-achievements-marker'));
      await tester.tap(marker);
      await tester.pumpAndSettle();
      expect(find.byType(AchievementsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _screenshot(tester, 'hall-${size.width.toInt()}');
      await tester.tap(find.text('First Steps'));
      await tester.pumpAndSettle();
      expect(find.text('Bronze'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _screenshot(tester, 'expanded-${size.width.toInt()}');
    });
  }
}

class _TestCompletionSource implements RunCompletionSource {
  final controller = StreamController<RunSubmissionResponse>.broadcast();

  @override
  Stream<RunSubmissionResponse> watch({
    required String userId,
    required String runSessionId,
  }) => controller.stream;
}

class _PendingRunSessionApi extends NoopRunSessionApi {
  @override
  Future<RunSubmissionResponse> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async => RunSubmissionResponse(
    SubmissionStatus(
      runSessionId: runSessionId,
      state: RunSessionState.pendingValidation,
      updatedAtMs: 1000,
    ),
  );
}

class _EmptySpool extends Fake implements RunSubmissionSpoolStore {
  @override
  Future<List<PendingRunSubmission>> loadAll() async => [];

  @override
  Future<PendingRunSubmission?> load({required String runSessionId}) async =>
      null;

  @override
  Future<void> remove({required String runSessionId}) async {}
}

Future<AppState> _boot({AchievementTestApi? api}) async {
  final app = AppState(
    authApi: AchievementTestAuth(),
    loadoutOwnershipApi:
        api ?? AchievementTestApi(achievementCanonical('earned')),
  );
  await app.bootstrap(force: true);
  return app;
}

Widget _host(
  AppState app, {
  Widget home = const AchievementsPage(),
  double textScale = 1,
}) => ChangeNotifierProvider<AppState>.value(
  value: app,
  child: RepaintBoundary(
    key: _boundary,
    child: MaterialApp(
      theme: createUiTheme(),
      debugShowCheckedModeBanner: false,
      onGenerateRoute: UiRouter.onGenerateRoute,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  ),
);

Future<void> _fonts() async {
  for (final font in {
    'CrimsonText': 'assets/fonts/Crimson_Text/CrimsonText-Regular.ttf',
    'Inter': 'assets/fonts/Inter/static/Inter_24pt-Regular.ttf',
    'Cinzel': 'assets/fonts/Cinzel/static/Cinzel-Regular.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  }.entries) {
    await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
  }
}

Future<void> _screenshot(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    final context = tester.element(find.byType(Scaffold).last);
    await precacheImage(
      const ResizeImage(AssetImage(TownMap.assetPath), width: 2048),
      context,
    );
    if (!context.mounted) return;
    await precacheImage(
      const AssetImage('assets/images/backgrounds/playHub_bgDark.png'),
      context,
    );
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image =
        await (_boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/achievements_review/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
