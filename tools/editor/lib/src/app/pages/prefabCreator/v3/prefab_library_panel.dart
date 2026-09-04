import 'package:flutter/material.dart';

import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/models/models.dart';
import '../../shared/editor_section_card.dart';
import 'prefab_owner_catalog_browser.dart';

/// Searchable Prefab library shell with an optional row-local owner editor.
class PrefabLibraryPanel extends StatelessWidget {
  const PrefabLibraryPanel({
    super.key,
    required this.document,
    required this.selectedPrefab,
    required this.expandedPrefab,
    required this.workspaceRootPath,
    required this.onSelected,
    required this.selectedDetailsBuilder,
  });

  final PrefabV3Document document;
  final PrefabV3Def? selectedPrefab;
  final PrefabV3Def? expandedPrefab;
  final String workspaceRootPath;
  final ValueChanged<PrefabV3Def> onSelected;
  final Widget Function(BuildContext context, PrefabV3Def prefab)
  selectedDetailsBuilder;

  @override
  Widget build(BuildContext context) {
    final ownerEditorOpen = expandedPrefab != null;
    return SingleChildScrollView(
      key: const ValueKey<String>('prefab_owner_sidebar'),
      child: EditorSectionCard(
        key: const ValueKey<String>('prefab_owner_library_section'),
        expansionKey: const ValueKey<String>(
          'prefab_owner_library_section_toggle',
        ),
        title: 'Prefab library',
        description: 'Search, filter, select, and edit prefabs.',
        trailing: Text('${document.data.prefabs.length} total'),
        collapsible: !ownerEditorOpen,
        initiallyExpanded: false,
        expanded: ownerEditorOpen ? true : null,
        child: document.data.prefabs.isEmpty
            ? const Text(
                'No prefabs remain. Create one from an authored atlas slice '
                'or platform.',
              )
            : PrefabOwnerCatalogBrowser(
                prefabs: document.data.prefabs,
                prefabData: document.data,
                tileData: document.tileData,
                visualBoundsByPrefabKey: document.visualBoundsByPrefabKey,
                workspaceRootPath: workspaceRootPath,
                selectedPrefabKey: selectedPrefab?.prefabKey,
                expandedPrefabKey: expandedPrefab?.prefabKey,
                changedPrefabKeys: document.changedPrefabKeys,
                downstreamImpacts: document.downstreamImpacts,
                enabled: true,
                onSelected: onSelected,
                selectedDetailsBuilder: selectedDetailsBuilder,
              ),
      ),
    );
  }
}
