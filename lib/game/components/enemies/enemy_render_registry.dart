import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';

import '../sprite_anim/actor_render_registry.dart';

/// Enemy catalog metadata wired to the shared actor sprite loader.
class EnemyRenderRegistry extends ActorRenderRegistry<EnemyId> {
  EnemyRenderRegistry({EnemyCatalog enemyCatalog = const EnemyCatalog()})
    : super({
        for (final id in EnemyId.values)
          id: ActorRenderEntry(
            renderAnim: enemyCatalog.get(id).renderAnim,
            scale: enemyCatalog.get(id).renderScale,
          ),
      });
}
