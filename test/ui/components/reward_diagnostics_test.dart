import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/components/reward_value_paint.dart';
import 'package:rpg_runner/ui/run/run_reward_diagnostics.dart';

void main() {
  late RunRewardDiagnostics original;
  late RunRewardDiagnostics diagnostics;
  late List<Map<String, dynamic>> events;
  setUp(() {
    original = RunRewardDiagnostics.instance;
    events = [];
    diagnostics = RunRewardDiagnostics(
      enabled: true,
      sink: (line) => events.add(jsonDecode(line) as Map<String, dynamic>),
    );
    RunRewardDiagnostics.instance = diagnostics;
  });
  tearDown(() => RunRewardDiagnostics.instance = original);

  test(
    'a logging failure preserves success and the original operation error',
    () async {
      final broken = RunRewardDiagnostics(
        enabled: true,
        sink: (_) => throw StateError('broken output'),
      );
      expect(await broken.measure('run', 'save', () async => 7), 7);
      final error = StateError('save failed');
      await expectLater(
        broken.measure<void>('run', 'save', () async => throw error),
        throwsA(same(error)),
      );
    },
  );

  test('concurrent and failed operations have distinct paired spans', () async {
    final gate = Completer<int>();
    final first = diagnostics.measure('run', 'upload', () => gate.future);
    final error = StateError('offline');
    await expectLater(
      diagnostics.measure<void>('run', 'poll', () async => throw error),
      throwsA(same(error)),
    );
    gate.complete(3);
    expect(await first, 3);
    expect(events.where((e) => e['outcome'] == 'started'), hasLength(2));
    for (final start in events.where((e) => e['outcome'] == 'started')) {
      final end = events.lastWhere((e) => e['span'] == start['span']);
      expect(end['outcome'], start['stage'] == 'poll' ? 'failed' : 'completed');
      expect(
        end['monoUs'] as int,
        greaterThanOrEqualTo(start['monoUs'] as int),
      );
      expect(end['durationUs'] as int, greaterThanOrEqualTo(0));
    }
  });

  Widget value({bool offstage = false, int revision = 2, int xp = 10}) =>
      MaterialApp(
        home: Offstage(
          offstage: offstage,
          child: RewardValuePaint(
            revision: revision,
            metric: 'xp',
            value: xp,
            target: 20,
            surface: 'hub',
            child: Text('$xp'),
          ),
        ),
      );
  Iterable<Map<String, dynamic>> frames() =>
      events.where((e) => (e['stage'] as String).endsWith('_frame'));

  testWidgets('offstage and stale revision paints cannot claim visibility', (
    tester,
  ) async {
    diagnostics.canonical('run', revision: 2, gold: 1, xp: 20);
    await tester.pumpWidget(value(offstage: true));
    expect(frames(), isEmpty);
    await tester.pumpWidget(value(revision: 1));
    expect(frames(), isEmpty);
    await tester.pumpWidget(value());
    expect(frames().map((e) => e['stage']), ['xp_frame']);
    await tester.pumpWidget(value(xp: 20));
    expect(frames().map((e) => e['stage']), ['xp_frame', 'xp_target_frame']);
    await tester.pumpWidget(value(xp: 20));
    expect(frames(), hasLength(2));
  });

  testWidgets('a covered route waits until it becomes current', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: RewardValuePaint(
          revision: 2,
          metric: 'gold',
          value: 1,
          target: 1,
          surface: 'hub',
          child: const Text('1'),
        ),
      ),
    );
    navigator.currentState!.push(
      PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (_, _, _) => const Center(child: Text('cover')),
      ),
    );
    await tester.pumpAndSettle();
    diagnostics.canonical('run', revision: 2, gold: 1, xp: 20);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: RewardValuePaint(
          revision: 2,
          metric: 'gold',
          value: 1,
          target: 1,
          surface: 'hub',
          child: const Text('1'),
        ),
      ),
    );
    expect(frames(), isEmpty);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(frames().map((e) => e['stage']), [
      'gold_frame',
      'gold_target_frame',
    ]);
  });

  test('account reset discards pending presentation correlation', () {
    diagnostics.canonical('run', revision: 2, gold: 1, xp: 20);
    diagnostics.clear();
    diagnostics.painted(
      revision: 2,
      metric: 'gold',
      value: 1,
      target: 1,
      surface: 'hub',
    );
    expect(frames(), isEmpty);
  });
}
