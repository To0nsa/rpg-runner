import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/progression/run_rewards.dart';

void main() {
  test('computeGoldEarned returns collectible count', () {
    expect(computeGoldEarned(collectiblesCollected: 0), 0);
    expect(computeGoldEarned(collectiblesCollected: 17), 17);
  });
}
