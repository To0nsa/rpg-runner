import 'dart:async';

import 'package:runner_core/util/cooperative_work_yield.dart';
import 'package:test/test.dart';

void main() {
  test(
    'yields past microtasks and preserves concurrent request order',
    () async {
      final completed = <int>[];
      final pending = [
        for (var index = 0; index < 4; index++)
          yieldCooperativeWork().then((_) => completed.add(index)),
      ];
      expect(completed, isEmpty);
      await Future<void>.value();
      expect(completed, isEmpty);
      await Future.wait(pending);
      expect(completed, orderedEquals([0, 1, 2, 3]));
    },
  );

  test('a continuation schedules new work in another event turn', () async {
    var nestedComplete = false;
    late Future<void> nested;
    await yieldCooperativeWork().then((_) {
      nested = yieldCooperativeWork().then((_) => nestedComplete = true);
    });
    expect(nestedComplete, isFalse);
    await nested;
    expect(nestedComplete, isTrue);
  });
}
