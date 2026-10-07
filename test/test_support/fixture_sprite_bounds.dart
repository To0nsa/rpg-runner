import 'dart:math' as math;

import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_id.dart';

/// Blank test atlases must cover explicit source rectangles as well as strips.
({int width, int height}) fixtureSpriteBounds({int minimum = 3072}) {
  final regions = [
    ...TrapId.values.expand(TrapCatalog.sourceRegions),
    ...EnemyId.values.expand(
      (id) => const EnemyCatalog()
          .get(id)
          .renderAnim
          .sourceFramesByKey
          .values
          .expand((frames) => frames),
    ),
  ];
  return (
    width: regions.fold(minimum, (v, r) => math.max(v, r.x + r.width)),
    height: regions.fold(minimum, (v, r) => math.max(v, r.y + r.height)),
  );
}
