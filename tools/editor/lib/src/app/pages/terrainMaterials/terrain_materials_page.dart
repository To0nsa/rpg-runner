import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terrain_materials/terrain_materials.dart';

import '../../../atlas/atlas_grid_settings_cache.dart';
import '../../../domain/authoring_types.dart';
import '../../../session/editor_session_controller.dart';
import '../../../terrain_materials/terrain_material_domain_models.dart';
import '../shared/editor_list_card.dart';
import '../shared/editor_panel_card.dart';
import '../shared/editor_three_panel_layout.dart';
import '../shared/editor_workspace_card.dart';
import 'terrain_material_dialog.dart';
import '../shared/terrain_material_preview.dart';

/// Repository-backed catalog for terrain fill, edge, and cliff-cap visuals.
class TerrainMaterialsPage extends StatefulWidget {
  const TerrainMaterialsPage({super.key, required this.controller});

  final EditorSessionController controller;

  @override
  State<TerrainMaterialsPage> createState() => _TerrainMaterialsPageState();
}

class _TerrainMaterialsPageState extends State<TerrainMaterialsPage> {
  final AtlasGridSettingsCache _gridSettingsCache = AtlasGridSettingsCache();
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    _gridSettingsCache.ensureWorkspace(widget.controller.workspacePath);
    widget.controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.controller.loadWorkspace());
    });
  }

  @override
  void didUpdateWidget(covariant TerrainMaterialsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
    _gridSettingsCache.ensureWorkspace(widget.controller.workspacePath);
    _reconcileSelection();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.controller.scene;
    if (widget.controller.isLoading && scene == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.controller.loadError case final error?) {
      return Center(child: Text('Could not load terrain materials: $error'));
    }
    if (scene is! TerrainMaterialScene) {
      return const Center(child: Text('No terrain material catalog loaded.'));
    }

    final selected = _selectedMaterial(scene);
    return EditorWorkspaceCard(
      child: EditorThreePanelLayout(
        firstLabel: 'Materials',
        secondLabel: 'Preview',
        thirdLabel: 'Details',
        firstFlex: 3,
        secondFlex: 5,
        thirdFlex: 4,
        first: _buildMaterialList(scene, selected),
        second: _buildPreview(scene, selected),
        third: _buildDetails(scene, selected),
      ),
    );
  }

  Widget _buildMaterialList(
    TerrainMaterialScene scene,
    TerrainMaterialDefinition? selected,
  ) => EditorPanelCard(
    title: 'Terrain materials',
    description: 'Reusable polygon visuals authored by stable material key.',
    bodyMode: EditorPanelBodyMode.expanded,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.icon(
              key: const ValueKey<String>('terrain_material_new'),
              onPressed: () => unawaited(_createMaterial(scene)),
              icon: const Icon(Icons.add),
              label: const Text('New'),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('terrain_material_duplicate'),
              onPressed: selected == null
                  ? null
                  : () => unawaited(_duplicateMaterial(scene, selected)),
              icon: const Icon(Icons.content_copy_outlined),
              label: const Text('Duplicate'),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('terrain_material_delete'),
              onPressed:
                  selected == null ||
                      scene.referencedMaterialKeys.contains(selected.key)
                  ? null
                  : () => unawaited(_deleteMaterial(selected)),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: scene.materials.isEmpty
              ? const Center(child: Text('No materials defined.'))
              : ListView(
                  children: <Widget>[
                    for (final material in scene.materials)
                      EditorListCard(
                        key: ValueKey<String>(
                          'terrain_material_row_${material.key}',
                        ),
                        isSelected: material.key == selected?.key,
                        onTap: () => setState(() {
                          _selectedKey = material.key;
                        }),
                        trailing: Tooltip(
                          message:
                              scene.referencedMaterialKeys.contains(
                                material.key,
                              )
                              ? 'Referenced by authored polygons'
                              : 'Not currently referenced',
                          child: Icon(
                            scene.referencedMaterialKeys.contains(material.key)
                                ? Icons.link
                                : Icons.link_off,
                            size: 18,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              material.displayName,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 3),
                            Text('${material.key} · rev ${material.revision}'),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    ),
  );

  Widget _buildPreview(
    TerrainMaterialScene scene,
    TerrainMaterialDefinition? selected,
  ) => EditorPanelCard(
    title: 'Composed preview',
    description:
        'Fill, edge bands, details, and endpoint caps at authored anchors.',
    bodyMode: EditorPanelBodyMode.scrollable,
    trailing: OutlinedButton.icon(
      key: const ValueKey<String>('terrain_material_edit'),
      onPressed: selected == null
          ? null
          : () => unawaited(_editMaterial(scene, selected)),
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Edit'),
    ),
    child: selected == null
        ? const Center(child: Text('Select or create a material.'))
        : TerrainMaterialPreview(
            workspaceRootPath: scene.workspaceRootPath,
            material: selected,
          ),
  );

  Widget _buildDetails(
    TerrainMaterialScene scene,
    TerrainMaterialDefinition? selected,
  ) {
    final issues = selected == null
        ? widget.controller.issues
        : widget.controller.issues
              .where(
                (issue) =>
                    issue.ownerKey == null || issue.ownerKey == selected.key,
              )
              .toList(growable: false);
    final referenced =
        selected != null && scene.referencedMaterialKeys.contains(selected.key);
    return EditorPanelCard(
      title: 'Coverage & diagnostics',
      description: 'Exact orientations are explicit; missing bands use fill.',
      bodyMode: EditorPanelBodyMode.scrollable,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (selected case final material?) ...<Widget>[
            Text('Identity', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            SelectableText('${material.displayName}\n${material.key}'),
            const SizedBox(height: 6),
            Text(
              referenced
                  ? 'Referenced by prefab or chunk polygons. Rename/delete is protected.'
                  : 'No authored polygon currently references this key.',
            ),
            const Divider(height: 28),
            Text(
              'Edge coverage',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _coverageRow('Top / slope', true),
            _coverageRow('Left wall', material.leftWall != null),
            _coverageRow('Right wall', material.rightWall != null),
            _coverageRow('Underside', material.underside != null),
            _coverageRow(
              'Cliff caps',
              material.topStartCap != null && material.topEndCap != null,
            ),
            const Divider(height: 28),
          ],
          Text(
            'Diagnostics (${issues.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (issues.isEmpty)
            const Text('No validation issues.')
          else
            for (final issue in issues) _issueTile(issue),
          const Divider(height: 28),
          Text(
            widget.controller.pendingChanges.hasChanges
                ? 'One manifest has pending changes.'
                : 'No pending material changes.',
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey<String>('terrain_material_apply'),
            onPressed:
                !widget.controller.pendingChanges.hasChanges ||
                    widget.controller.errorCount > 0 ||
                    widget.controller.isExporting
                ? null
                : () => unawaited(_applyChanges()),
            icon: widget.controller.isExporting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Apply manifest'),
          ),
        ],
      ),
    );
  }

  Widget _coverageRow(String label, bool configured) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: <Widget>[
        Icon(
          configured ? Icons.check_circle_outline : Icons.remove_circle_outline,
          size: 18,
          color: configured
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(configured ? 'Configured' : 'Fill only'),
      ],
    ),
  );

  Widget _issueTile(ValidationIssue issue) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text('[${issue.code}] ${issue.message}'),
  );

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(_reconcileSelection);
  }

  void _reconcileSelection() {
    final scene = widget.controller.scene;
    if (scene is! TerrainMaterialScene || scene.materials.isEmpty) {
      _selectedKey = null;
      return;
    }
    if (scene.materials.every((material) => material.key != _selectedKey)) {
      _selectedKey = scene.materials.first.key;
    }
  }

  TerrainMaterialDefinition? _selectedMaterial(TerrainMaterialScene scene) {
    for (final material in scene.materials) {
      if (material.key == _selectedKey) return material;
    }
    return scene.materials.isEmpty ? null : scene.materials.first;
  }

  Future<void> _createMaterial(TerrainMaterialScene scene) async {
    final result = await showTerrainMaterialDialog(
      context,
      workspaceRootPath: scene.workspaceRootPath,
      existingKeys: scene.materials.map((material) => material.key).toSet(),
      atlasImages: scene.atlasImages,
      gridSettingsCache: _gridSettingsCache,
      suggestedKey: _allocateKey('new_material', scene.materials),
      isNew: true,
    );
    _upsert(result);
  }

  Future<void> _duplicateMaterial(
    TerrainMaterialScene scene,
    TerrainMaterialDefinition source,
  ) async {
    final duplicateKey = _allocateKey('${source.key}_copy', scene.materials);
    final duplicate = source.copyWith(
      key: duplicateKey,
      displayName: '${source.displayName} Copy',
      revision: 1,
    );
    final result = await showTerrainMaterialDialog(
      context,
      workspaceRootPath: scene.workspaceRootPath,
      existingKeys: scene.materials.map((material) => material.key).toSet(),
      atlasImages: scene.atlasImages,
      gridSettingsCache: _gridSettingsCache,
      material: duplicate,
      isNew: true,
    );
    if (result == null) return;
    _upsert(
      TerrainMaterialEditResult(previousKey: '', material: result.material),
    );
  }

  Future<void> _editMaterial(
    TerrainMaterialScene scene,
    TerrainMaterialDefinition material,
  ) async {
    final result = await showTerrainMaterialDialog(
      context,
      workspaceRootPath: scene.workspaceRootPath,
      existingKeys: scene.materials.map((item) => item.key).toSet(),
      atlasImages: scene.atlasImages,
      gridSettingsCache: _gridSettingsCache,
      material: material,
      allowKeyChange: !scene.referencedMaterialKeys.contains(material.key),
    );
    _upsert(result);
  }

  void _upsert(TerrainMaterialEditResult? result) {
    if (result == null || !mounted) return;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'upsert_material',
        payload: <String, Object?>{
          'previousKey': result.previousKey,
          'material': result.material,
        },
      ),
    );
    setState(() {
      _selectedKey = result.material.key;
    });
  }

  Future<void> _deleteMaterial(TerrainMaterialDefinition material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete terrain material?'),
        content: Text(
          'Delete "${material.displayName}" (${material.key}) from the manifest?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'delete_material',
        payload: <String, Object?>{'key': material.key},
      ),
    );
  }

  Future<void> _applyChanges() async {
    await widget.controller.exportDirectWrite();
    if (!mounted) return;
    final error = widget.controller.exportError;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? 'Terrain material manifest applied.'
              : 'Apply failed: $error',
        ),
      ),
    );
  }
}

String _allocateKey(String base, List<TerrainMaterialDefinition> materials) {
  final keys = materials.map((material) => material.key).toSet();
  if (!keys.contains(base)) return base;
  var suffix = 2;
  while (keys.contains('${base}_$suffix')) {
    suffix += 1;
  }
  return '${base}_$suffix';
}
