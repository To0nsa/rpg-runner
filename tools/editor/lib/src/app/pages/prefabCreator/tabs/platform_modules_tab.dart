part of '../prefab_creator_page.dart';

extension _PrefabCreatorPlatformModulesTab on _PrefabCreatorPageState {
  Widget _buildPlatformModulesTab() {
    final tileSlices = _data.tileSlices;
    final modules = _data.platformModules;
    final selectedModule = _selectedModule();
    final sceneValues = _prefabSceneValuesFromInputs();
    final workspaceRootPath = widget.controller.workspacePath.trim();
    final isSelectedDeprecated =
        selectedModule?.status == TileModuleStatus.deprecated;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: ExpansionTile(
                    key: const ValueKey<String>(
                      'platform_module_advanced_controls',
                    ),
                    initiallyExpanded: false,
                    title: const Text('Advanced Module Controls'),
                    subtitle: const Text(
                      'Create, rename, duplicate, deprecate, and select modules.',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: [
                      TextField(
                        controller: _moduleIdController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Platform Module ID',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _moduleTileSizeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Tile Size (px)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _upsertModuleFromForm,
                            icon: const Icon(Icons.add_box_outlined),
                            label: const Text('Add/Update Module'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _renameSelectedModuleFromForm,
                            icon: const Icon(Icons.drive_file_rename_outline),
                            label: const Text('Rename'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _duplicateSelectedModule,
                            icon: const Icon(Icons.copy_outlined),
                            label: const Text('Duplicate'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _toggleDeprecateSelectedModule,
                            icon: Icon(
                              isSelectedDeprecated
                                  ? Icons.unarchive_outlined
                                  : Icons.archive_outlined,
                            ),
                            label: Text(
                              isSelectedDeprecated ? 'Reactivate' : 'Deprecate',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey<String?>(
                          'module_${_selectedModuleId ?? 'none'}',
                        ),
                        initialValue: _selectedModuleId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Edit Module',
                        ),
                        items: [
                          for (final module in modules)
                            DropdownMenuItem<String>(
                              value: module.id,
                              child: Text(
                                module.status == TileModuleStatus.deprecated
                                    ? '${module.id} (deprecated)'
                                    : module.id,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          _updateState(() {
                            _selectedModuleId = value;
                            if (value != null) {
                              final module = modules.firstWhere(
                                (m) => m.id == value,
                              );
                              _moduleIdController.text = module.id;
                              _moduleTileSizeController.text = module.tileSize
                                  .toString();
                            }
                          });
                        },
                      ),
                      if (selectedModule != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Selected: key=${selectedModule.id} '
                          'rev=${selectedModule.revision} '
                          'status=${selectedModule.status.jsonValue}',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Scene Tool',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tool in PlatformModuleSceneTool.values)
                      ChoiceChip(
                        key: ValueKey<String>('module_tool_${tool.name}'),
                        label: Text(tool.label),
                        selected: _selectedModuleSceneTool == tool,
                        onSelected: (selected) {
                          if (!selected) {
                            return;
                          }
                          _updateState(() {
                            _selectedModuleSceneTool = tool;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tile Slice Palette',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (tileSlices.isEmpty)
                  const Text(
                    'No tile slices yet. Create tile slices in Atlas Slicer first.',
                  )
                else
                  _buildTileSlicePalette(tileSlices),
                const SizedBox(height: 16),
                _buildPlatformPrefabOutputPanel(
                  selectedModule: selectedModule,
                  sceneValues: sceneValues,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Module Scene',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 3,
                child: selectedModule == null
                    ? const Card(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Select or create a module to edit it.',
                            ),
                          ),
                        ),
                      )
                    : PlatformModuleSceneView(
                        workspaceRootPath: workspaceRootPath,
                        module: selectedModule,
                        tileSlices: tileSlices,
                        tool: _selectedModuleSceneTool,
                        selectedTileSliceId: _selectedTileSliceId,
                        overlayValues: sceneValues,
                        onOverlayValuesChanged: _onPrefabSceneValuesChanged,
                        onPaintCell: (gridX, gridY, sliceId) {
                          _paintCellInSelectedModuleAt(
                            gridX: gridX,
                            gridY: gridY,
                            sliceId: sliceId,
                          );
                        },
                        onEraseCell: (gridX, gridY) {
                          _eraseCellInSelectedModuleAt(
                            gridX: gridX,
                            gridY: gridY,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                'Platform Modules',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 2,
                child: modules.isEmpty
                    ? const Text('No platform modules yet.')
                    : ListView.builder(
                        itemCount: modules.length,
                        itemBuilder: (context, index) {
                          final module = modules[index];
                          return Card(
                            child: ExpansionTile(
                              title: Text(module.id),
                              subtitle: Text(
                                'status=${module.status.jsonValue} '
                                'rev=${module.revision} '
                                'tileSize=${module.tileSize} '
                                'cells=${module.cells.length}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteModule(module.id),
                              ),
                              children: [
                                if (module.cells.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('No cells yet.'),
                                    ),
                                  ),
                                for (var i = 0; i < module.cells.length; i += 1)
                                  ListTile(
                                    dense: true,
                                    title: Text(module.cells[i].sliceId),
                                    subtitle: Text(
                                      'x=${module.cells[i].gridX} y=${module.cells[i].gridY}',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _deleteModuleCell(
                                        moduleId: module.id,
                                        cellIndex: i,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformPrefabOutputPanel({
    required TileModuleDef? selectedModule,
    required PrefabSceneValues? sceneValues,
  }) {
    final isEnabled = selectedModule != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform Prefab Output',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Set anchor/collider here and save a platform prefab directly from this module.',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: isEnabled
                  ? _loadPlatformPrefabForSelectedModule
                  : null,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Load Prefab For Module'),
            ),
            FilledButton.icon(
              onPressed: isEnabled
                  ? _upsertPlatformPrefabForSelectedModule
                  : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Create/Update Platform Prefab'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _prefabIdController,
          enabled: isEnabled,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Platform Prefab ID',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _anchorXController,
                enabled: isEnabled,
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
                enabled: isEnabled,
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
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _colliderOffsetXController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Collider Offset X',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _colliderOffsetYController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Collider Offset Y',
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
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Collider Width',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _colliderHeightController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Collider Height',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _prefabZIndexController,
          enabled: isEnabled,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Z Index',
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _prefabSnapToGrid,
          onChanged: !isEnabled
              ? null
              : (value) {
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
          enabled: isEnabled,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Tags (comma separated)',
          ),
        ),
        if (sceneValues == null) ...[
          const SizedBox(height: 8),
          const Text(
            'Anchor/collider fields contain invalid values. '
            'Fix them before saving the prefab.',
          ),
        ],
      ],
    );
  }

  Widget _buildTileSlicePalette(List<AtlasSliceDef> tileSlices) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final slice in tileSlices)
          ChoiceChip(
            label: Text('${slice.id} (${slice.width}x${slice.height})'),
            selected: _selectedTileSliceId == slice.id,
            onSelected: (selected) {
              if (!selected) {
                return;
              }
              _updateState(() {
                _selectedTileSliceId = slice.id;
              });
            },
          ),
      ],
    );
  }
}
