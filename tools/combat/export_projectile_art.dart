import 'dart:convert';
import 'dart:io';

import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/projectiles/projectile_render_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';

void main() {
  final result = <String, dynamic>{};
  for (final id in ProjectileId.values.where(
    (id) => id != ProjectileId.unknown && id != ProjectileId.poisonDart,
  )) {
    final r = const ProjectileRenderCatalog().get(id);
    result[id.name] = {
      'scale': ProjectileRenderCatalog.scaleFor(id),
      'w': r.frameWidth,
      'h': r.frameHeight,
      'x': r.anchorPoint.x,
      'y': r.anchorPoint.y,
      'keys': {
        for (final key in [AnimKey.spawn, AnimKey.idle])
          if (r.sourcesByKey.containsKey(key))
            key.name: {
              'path': r.sourcesByKey[key],
              'count': r.frameCountsByKey[key],
              'start': r.frameStartByKey[key] ?? 0,
              'row': r.rowByKey[key] ?? 0,
              'cols': r.gridColumnsByKey[key],
            },
      },
    };
  }
  stdout.write(jsonEncode(result));
}
