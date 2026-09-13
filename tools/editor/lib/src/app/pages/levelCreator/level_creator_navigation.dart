import 'package:flutter/foundation.dart';

import '../../../domain/authoring_types.dart';
import '../../../levels/level_domain_models.dart';
import '../shared/editor_page_navigation_state.dart';

/// Workspace views remain transient and never enter authored Level data.
enum LevelCreatorTab { contents, flow, appearance }

/// The editor restores this context after a domain-owned content save.
/// Stable source IDs are revalidated by the destination; missing items may be
/// cleared without changing the selected Level's authored content.
@immutable
class LevelCreatorReturnContext extends EditorPageLocation {
  const LevelCreatorReturnContext({
    required this.levelId,
    this.tab = LevelCreatorTab.contents,
    this.selectedChunkKey,
    this.selectedSegmentId,
    this.groupFilter,
    this.previewSeed = 4401,
    this.librarySearch = '',
    this.chunkSearch = '',
    this.showLevelSettings = true,
  });

  final String levelId;
  final LevelCreatorTab tab;
  final String? selectedChunkKey;
  final String? selectedSegmentId;
  final String? groupFilter;
  final int previewSeed;
  final String librarySearch;
  final String chunkSearch;
  final bool showLevelSettings;

  @override
  AuthoringDocument restoreDocumentSelection(
    AuthoringDomainPlugin plugin,
    AuthoringDocument document,
  ) {
    if (document is! LevelDefsDocument ||
        findLevelDefById(document.levels, levelId) == null) {
      return document;
    }
    return plugin.applyEdit(
      document,
      AuthoringCommand(kind: 'set_active_level', payload: {'levelId': levelId}),
    );
  }
}

/// A flat starter is distinct from normal empty/deprecated Chunk creation.
enum LevelCreatorChunkIntent { edit, create, flatStarter, assignGroup }

/// Requests guarded Chunk-domain navigation without granting the Level page
/// ownership of Chunk geometry, metadata, identity allocation, or persistence.
@immutable
class LevelCreatorChunkTarget {
  const LevelCreatorChunkTarget({
    required this.levelId,
    required this.intent,
    required this.returnContext,
    this.chunkKey,
    this.groupId,
  });

  final String levelId;
  final LevelCreatorChunkIntent intent;
  final String? chunkKey;
  final String? groupId;
  final LevelCreatorReturnContext returnContext;
}

/// Resolves only unambiguous authored owners. Shared atlas image paths do not
/// identify a domain by themselves and must retain the diagnostic evidence.
String? levelDependencyPluginForPath(String? sourcePath) {
  final path = sourcePath?.replaceAll('\\', '/').toLowerCase();
  if (path == null) return null;
  if (path.endsWith('/parallax_defs.json') ||
      path.contains('assets/images/parallax/')) {
    return 'parallax';
  }
  if (path.contains('assets/authoring/level/chunks/')) return 'chunks';
  if (path.endsWith('/prefab_defs.json') || path.endsWith('/tile_defs.json')) {
    return 'prefabs';
  }
  if (path.endsWith('/terrain_material_defs.json')) return 'terrain_materials';
  return null;
}
