import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/state/run/run_submission_scheduler.dart';

void main() {
  testWidgets('old backlog shares one minute lane while new runs stay prompt', (
    tester,
  ) async {
    var now = 0;
    final calls = <String>[];
    final scheduler = RunSubmissionScheduler(
      clock: () => now,
      process: (id) async {
        calls.add(id);
        return id == 'new' ? null : 0;
      },
    );
    addTearDown(scheduler.dispose);
    scheduler.setForeground(true);
    scheduler.track('old-a');
    scheduler.track('old-b');
    for (var second = 0; second < 700; second++) {
      now += 1000;
      await tester.pump(const Duration(seconds: 1));
    }
    final before = calls.length;
    scheduler.track('new');
    now += 1000;
    await tester.pump(const Duration(seconds: 1));
    expect(calls.last, 'new');
    for (var second = 0; second < 59; second++) {
      now += 1000;
      await tester.pump(const Duration(seconds: 1));
    }
    expect(calls.length - before, lessThanOrEqualTo(2));
    scheduler.dispose();
  });

  testWidgets('one queue deduplicates, serializes and spaces all runs', (
    tester,
  ) async {
    var now = 0;
    final calls = <String>[];
    final gate = Completer<int?>();
    final scheduler = RunSubmissionScheduler(
      clock: () => now,
      process: (id) async {
        calls.add(id);
        if (id == 'first') return gate.future;
        return null;
      },
    );
    addTearDown(scheduler.dispose);
    scheduler.track('first');
    scheduler.track('first');
    await tester.pump(Duration.zero);
    expect(calls, isEmpty);
    scheduler.setForeground(true);
    await tester.pump(Duration.zero);
    expect(calls, ['first']);
    scheduler.track('second');
    now = 20000;
    await tester.pump(const Duration(seconds: 20));
    expect(calls, ['first']);
    gate.complete(null);
    await tester.pump(Duration.zero);
    now += 999;
    await tester.pump(const Duration(milliseconds: 999));
    expect(calls, ['first']);
    now += 1;
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, ['first', 'second']);
  });

  testWidgets('suspend, clear during a request, and retry after errors', (
    tester,
  ) async {
    var now = 0;
    var calls = 0;
    final gate = Completer<int?>();
    final scheduler = RunSubmissionScheduler(
      clock: () => now,
      process: (_) async {
        calls++;
        if (calls == 1) return gate.future;
        if (calls == 2) throw StateError('offline');
        return null;
      },
    );
    addTearDown(scheduler.dispose);
    scheduler.setForeground(true);
    scheduler.track('old');
    await tester.pump(Duration.zero);
    scheduler.clear();
    scheduler.track('new');
    scheduler.setForeground(false);
    gate.complete(0);
    await tester.pump(Duration.zero);
    now = 20000;
    await tester.pump(const Duration(seconds: 20));
    expect(calls, 1);
    scheduler.setForeground(true);
    await tester.pump(Duration.zero);
    expect(calls, 2);
    now += 10000;
    await tester.pump(const Duration(seconds: 10));
    expect(calls, 3);
    now += 120000;
    await tester.pump(const Duration(minutes: 2));
    expect(calls, 3);
  });
}
