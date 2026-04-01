part of '../prefab_creator_page.dart';

extension _PrefabCreatorPrefabsTab on _PrefabCreatorPageState {
  Widget _buildPrefabInspectorTab() {
    final prefabSlices = _data.prefabSlices;
    final platformModules = _data.platformModules;
    final prefabs = _data.prefabs;
    final selectedSlice = _selectedPrefabKind == PrefabKind.obstacle
        ? _findSliceById(slices: prefabSlices, sliceId: _selectedPrefabSliceId)
        : null;
    final selectedModule = _selectedPrefabKind == PrefabKind.platform
        ? _findModuleById(
            modules: platformModules,
            moduleId: _selectedPrefabPlatformModuleId,
          )
        : null;
    final sceneValues = _prefabSceneValuesFromInputs();
    final editingPrefab = _editingPrefab();
    final workspaceRootPath = widget.controller.workspacePath.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _buildPrefabScenePanel(
                  workspaceRootPath: workspaceRootPath,
                  selectedKind: _selectedPrefabKind,
                  selectedSlice: selectedSlice,
                  selectedModule: selectedModule,
                  sceneValues: sceneValues,
                ),
              ),
              const SizedBox(height: 12),
              Text('Prefabs', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Expanded(
                flex: 1,
                child: prefabs.isEmpty
                    ? const Text('No prefabs yet.')
                    : ListView.builder(
                        itemCount: prefabs.length,
                        itemBuilder: (context, index) {
                          final prefab = prefabs[index];
                          final sourceSummary = prefab.usesAtlasSlice
                              ? 'atlas_slice:${prefab.sliceId}'
                              : prefab.usesPlatformModule
                              ? 'platform_module:${prefab.moduleId}'
                              : 'unknown';
                          return Card(
                            child: ListTile(
                              title: Text(prefab.id),
                              subtitle: Text(
                                'key=${prefab.prefabKey} '
                                'rev=${prefab.revision} '
                                'status=${prefab.status.jsonValue} '
                                'kind=${prefab.kind.jsonValue} '
                                'source=$sourceSummary '
                                'anchor=(${prefab.anchorXPx},${prefab.anchorYPx}) '
                                'colliders=${prefab.colliders.length} '
                                'z=${prefab.zIndex} '
                                'snap=${prefab.snapToGrid}',
                              ),
                              onTap: () => _loadPrefabIntoForm(prefab),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deletePrefab(prefab.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 420,
          child: _buildPrefabInspectorPanel(
            prefabSlices: prefabSlices,
            platformModules: platformModules,
            selectedSliceId: _selectedPrefabSliceId,
            selectedModuleId: _selectedPrefabPlatformModuleId,
            editingPrefab: editingPrefab,
          ),
        ),
      ],
    );
  }

  Widget _buildPrefabInspectorPanel({
    required List<AtlasSliceDef> prefabSlices,
    required List<TileModuleDef> platformModules,
    required String? selectedSliceId,
    required String? selectedModuleId,
    required PrefabDef? editingPrefab,
  }) {
    final hasObstacleSources = prefabSlices.isNotEmpty;
    final hasPlatformSources = platformModules.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasObstacleSources)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'No prefab slices yet. Obstacle prefabs require atlas slices.',
                ),
              ),
            if (!hasPlatformSources)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'No platform modules yet. Platform prefabs require modules.',
                ),
              ),
            if (editingPrefab != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Editing key=${editingPrefab.prefabKey} '
                  'rev=${editingPrefab.revision} '
                  'status=${editingPrefab.status.jsonValue}',
                ),
              ),
            TextField(
              controller: _prefabIdController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Prefab ID',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PrefabKind>(
              key: ValueKey<String>('prefab_kind_${_selectedPrefabKind.name}'),
              initialValue: _selectedPrefabKind,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Kind',
              ),
              items: const [
                DropdownMenuItem<PrefabKind>(
                  value: PrefabKind.obstacle,
                  child: Text('Obstacle'),
                ),
                DropdownMenuItem<PrefabKind>(
                  value: PrefabKind.platform,
                  child: Text('Platform'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                _updateState(() {
                  _selectedPrefabKind = value;
                  if (value == PrefabKind.obstacle &&
                      _selectedPrefabSliceId == null &&
                      prefabSlices.isNotEmpty) {
                    _selectedPrefabSliceId = prefabSlices.first.id;
                  }
                  if (value == PrefabKind.platform &&
                      _selectedPrefabPlatformModuleId == null &&
                      platformModules.isNotEmpty) {
                    _selectedPrefabPlatformModuleId = platformModules.first.id;
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Visual Source',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (_selectedPrefabKind == PrefabKind.obstacle)
              hasObstacleSources
                  ? DropdownButtonFormField<String>(
                      key: ValueKey<String?>(
                        'prefab_slice_${selectedSliceId ?? 'none'}',
                      ),
                      initialValue: selectedSliceId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Atlas Slice',
                      ),
                      items: [
                        for (final slice in prefabSlices)
                          DropdownMenuItem<String>(
                            value: slice.id,
                            child: Text(slice.id),
                          ),
                      ],
                      onChanged: (value) {
                        _updateState(() {
                          _selectedPrefabSliceId = value;
                        });
                      },
                    )
                  : const Text('Create prefab atlas slices first.')
            else
              hasPlatformSources
                  ? DropdownButtonFormField<String>(
                      key: ValueKey<String?>(
                        'prefab_module_${selectedModuleId ?? 'none'}',
                      ),
                      initialValue: selectedModuleId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Platform Module',
                      ),
                      items: [
                        for (final module in platformModules)
                          DropdownMenuItem<String>(
                            value: module.id,
                            child: Text(module.id),
                          ),
                      ],
                      onChanged: (value) {
                        _updateState(() {
                          _selectedPrefabPlatformModuleId = value;
                        });
                      },
                    )
                  : const Text('Create platform modules first.'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _anchorXController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Anchor X (px)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _anchorYController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Anchor Y (px)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Default Collider',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _colliderOffsetXController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Offset X',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _colliderOffsetYController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Offset Y',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _colliderWidthController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Width',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _colliderHeightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Height',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _prefabZIndexController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Z Index',
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _prefabSnapToGrid,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                _updateState(() {
                  _prefabSnapToGrid = value;
                });
              },
              title: const Text('Snap To Grid'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _prefabTagsController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Tags (comma separated)',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _upsertPrefabFromForm,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Add/Update Prefab'),
                ),
                OutlinedButton.icon(
                  onPressed: _duplicateLoadedPrefab,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Duplicate'),
                ),
                OutlinedButton.icon(
                  onPressed: _deprecateLoadedPrefab,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Deprecate'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearPrefabForm,
                  icon: const Icon(Icons.clear_outlined),
                  label: const Text('Clear Form'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrefabScenePanel({
    required String workspaceRootPath,
    required PrefabKind selectedKind,
    required AtlasSliceDef? selectedSlice,
    required TileModuleDef? selectedModule,
    required PrefabSceneValues? sceneValues,
  }) {
    if (sceneValues == null) {
      return const Card(
        child: SizedBox(
          height: 210,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Anchor/collider fields contain invalid values. '
                'Fix them to enable scene editing.',
              ),
            ),
          ),
        ),
      );
    }

    if (selectedKind == PrefabKind.platform) {
      if (selectedModule == null) {
        return const Card(
          child: SizedBox(
            height: 210,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select a platform module to preview anchor/collider overlays.',
                ),
              ),
            ),
          ),
        );
      }
      return _PlatformModuleSceneView(
        module: selectedModule,
        values: sceneValues,
        snapWarning: _platformSnapWarning(
          module: selectedModule,
          values: sceneValues,
        ),
      );
    }

    if (selectedSlice == null) {
      return const Card(
        child: SizedBox(
          height: 210,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select a prefab slice to edit anchor/collider visually.',
              ),
            ),
          ),
        ),
      );
    }

    return PrefabSceneView(
      workspaceRootPath: workspaceRootPath,
      slice: selectedSlice,
      values: sceneValues,
      onChanged: _onPrefabSceneValuesChanged,
    );
  }

  TileModuleDef? _findModuleById({
    required List<TileModuleDef> modules,
    required String? moduleId,
  }) {
    if (moduleId == null || moduleId.isEmpty) {
      return null;
    }
    for (final module in modules) {
      if (module.id == moduleId) {
        return module;
      }
    }
    return null;
  }

  String? _platformSnapWarning({
    required TileModuleDef module,
    required PrefabSceneValues values,
  }) {
    if (!_prefabSnapToGrid || module.tileSize <= 1) {
      return null;
    }
    final unsnappedFields = <String>[];
    if (values.anchorX % module.tileSize != 0) {
      unsnappedFields.add('anchorX');
    }
    if (values.anchorY % module.tileSize != 0) {
      unsnappedFields.add('anchorY');
    }
    if (values.colliderOffsetX % module.tileSize != 0) {
      unsnappedFields.add('colliderOffsetX');
    }
    if (values.colliderOffsetY % module.tileSize != 0) {
      unsnappedFields.add('colliderOffsetY');
    }
    if (values.colliderWidth % module.tileSize != 0) {
      unsnappedFields.add('colliderWidth');
    }
    if (values.colliderHeight % module.tileSize != 0) {
      unsnappedFields.add('colliderHeight');
    }
    if (unsnappedFields.isEmpty) {
      return null;
    }
    return 'Snap warning: ${unsnappedFields.join(', ')} must be multiples of '
        'tileSize ${module.tileSize}.';
  }
}

class _PlatformModuleSceneView extends StatelessWidget {
  const _PlatformModuleSceneView({
    required this.module,
    required this.values,
    this.snapWarning,
  });

  final TileModuleDef module;
  final PrefabSceneValues values;
  final String? snapWarning;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform Module Preview',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Module: ${module.id} | tileSize=${module.tileSize} | cells=${module.cells.length}',
            ),
            if (snapWarning != null) ...[
              const SizedBox(height: 4),
              Text(
                snapWarning!,
                style: const TextStyle(color: Color(0xFFFFC66D), fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF1B2A36)),
                ),
                child: CustomPaint(
                  painter: _PlatformModuleScenePainter(
                    module: module,
                    values: values,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformModuleScenePainter extends CustomPainter {
  const _PlatformModuleScenePainter({
    required this.module,
    required this.values,
  });

  final TileModuleDef module;
  final PrefabSceneValues values;

  @override
  void paint(Canvas canvas, Size size) {
    final fillBg = Paint()..color = const Color(0xFF111A22);
    canvas.drawRect(Offset.zero & size, fillBg);

    if (module.cells.isEmpty || module.tileSize <= 0) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'No module cells to preview.',
          style: TextStyle(color: Color(0xFFB6C6D2), fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 16);
      textPainter.paint(canvas, const Offset(8, 8));
      return;
    }

    var minX = module.cells.first.gridX;
    var maxX = module.cells.first.gridX;
    var minY = module.cells.first.gridY;
    var maxY = module.cells.first.gridY;
    for (final cell in module.cells) {
      if (cell.gridX < minX) {
        minX = cell.gridX;
      }
      if (cell.gridX > maxX) {
        maxX = cell.gridX;
      }
      if (cell.gridY < minY) {
        minY = cell.gridY;
      }
      if (cell.gridY > maxY) {
        maxY = cell.gridY;
      }
    }

    final cellsWide = (maxX - minX + 1).toDouble();
    final cellsHigh = (maxY - minY + 1).toDouble();
    final moduleWidthPx = cellsWide * module.tileSize;
    final moduleHeightPx = cellsHigh * module.tileSize;

    const margin = 24.0;
    final availableWidth = (size.width - (margin * 2)).clamp(1.0, size.width);
    final availableHeight = (size.height - (margin * 2)).clamp(
      1.0,
      size.height,
    );
    final scaleX = availableWidth / moduleWidthPx;
    final scaleY = availableHeight / moduleHeightPx;
    final scale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.2, 24.0);

    final drawWidth = moduleWidthPx * scale;
    final drawHeight = moduleHeightPx * scale;
    final origin = Offset(
      (size.width - drawWidth) * 0.5,
      (size.height - drawHeight) * 0.5,
    );

    final cellFill = Paint()..color = const Color(0xFF33556F);
    final cellStroke = Paint()
      ..color = const Color(0xFF8AB2D1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final cell in module.cells) {
      final left = origin.dx + ((cell.gridX - minX) * module.tileSize * scale);
      final top = origin.dy + ((cell.gridY - minY) * module.tileSize * scale);
      final rect = Rect.fromLTWH(
        left,
        top,
        module.tileSize * scale,
        module.tileSize * scale,
      );
      canvas.drawRect(rect, cellFill);
      canvas.drawRect(rect, cellStroke);
    }

    final anchor = Offset(
      origin.dx + (values.anchorX * scale),
      origin.dy + (values.anchorY * scale),
    );
    final colliderCenter = Offset(
      anchor.dx + (values.colliderOffsetX * scale),
      anchor.dy + (values.colliderOffsetY * scale),
    );
    final colliderRect = Rect.fromCenter(
      center: colliderCenter,
      width: values.colliderWidth * scale,
      height: values.colliderHeight * scale,
    );

    final colliderFill = Paint()
      ..color = const Color(0x4422D3EE)
      ..style = PaintingStyle.fill;
    final colliderStroke = Paint()
      ..color = const Color(0xFF7CE5FF)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawRect(colliderRect, colliderFill);
    canvas.drawRect(colliderRect, colliderStroke);

    final anchorCross = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..strokeWidth = 1.8;
    const arm = 6.0;
    canvas.drawLine(
      Offset(anchor.dx - arm, anchor.dy),
      Offset(anchor.dx + arm, anchor.dy),
      anchorCross,
    );
    canvas.drawLine(
      Offset(anchor.dx, anchor.dy - arm),
      Offset(anchor.dx, anchor.dy + arm),
      anchorCross,
    );
  }

  @override
  bool shouldRepaint(covariant _PlatformModuleScenePainter oldDelegate) {
    return oldDelegate.module != module || oldDelegate.values != values;
  }
}
