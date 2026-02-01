import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/progression/run_rewards.dart';

void main() {
  test('computeGoldEarned returns collectible count', () {
    expect(computeGoldEarned(collectiblesCollected: 0), 0);
    expect(computeGoldEarned(collectiblesCollected: 17), 17);
  });
}
