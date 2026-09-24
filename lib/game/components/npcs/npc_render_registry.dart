import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/npcs/npc_id.dart';

import '../sprite_anim/actor_render_registry.dart';

/// All supported allies preload their complete deterministic animation set.
class NpcRenderRegistry extends ActorRenderRegistry<NpcId> {
  NpcRenderRegistry({NpcCatalog catalog = const NpcCatalog()})
    : super({
        for (final id in NpcCatalog.supportedIds)
          id: ActorRenderEntry(
            renderAnim: catalog.get(id).renderAnim,
            scale: catalog.get(id).renderScale,
          ),
      });
}
