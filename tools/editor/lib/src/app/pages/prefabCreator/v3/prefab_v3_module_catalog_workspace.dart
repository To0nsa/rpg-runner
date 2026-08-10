import 'package:flutter/material.dart';

import '../../../../domain/authoring_types.dart';
import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/domain/prefab_domain_plugin.dart';
import '../../../../prefabs/domain/prefab_v3_catalog_commit.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../session/editor_session_controller.dart';
import '../platform_modules/platform_modules_tab.dart';
import '../platform_modules/widgets/platform_module_scene_view.dart';
import '../shared/platform_module_cell_reducer.dart';

/// Adapts the retained platform-module UI to typed Prefab-v3 commands.
///
/// The route keeps selection/tools/form drafts local while every module or cell
/// mutation crosses the stale-checked catalog command as one semantic commit.
class PrefabV3ModuleCatalogWorkspace extends StatefulWidget {
  const PrefabV3ModuleCatalogWorkspace({
    super.key,
    required this.controller,
    required this.document,
  });

  final EditorSessionController controller;
  final PrefabV3Document document;

  @override
  State<PrefabV3ModuleCatalogWorkspace> createState() =>
      PrefabV3ModuleCatalogWorkspaceState();
}

/// Local-draft contract used by the containing Prefab-v3 workspace shortcuts.
class PrefabV3ModuleCatalogWorkspaceState
    extends State<PrefabV3ModuleCatalogWorkspace> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _tileSizeController = TextEditingController(
    text: '16',
  );

  String? _selectedModuleId;
  String? _selectedTileSliceId;
  PlatformModuleSceneTool _tool = PlatformModuleSceneTool.paint;
  bool _syncingDraft = false;
  bool _hasDraftChanges = false;

  bool get hasLocalDraftChanges => _hasDraftChanges;

  @override
  void initState() {
    super.initState();
    _idController.addListener(_markDraftChanged);
    _tileSizeController.addListener(_markDraftChanged);
    _initialize(widget.document);
  }

  @override
  void didUpdateWidget(covariant PrefabV3ModuleCatalogWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.document, widget.document)) {
      _reconcile(widget.document);
    }
  }

  @override
  void dispose() {
    _idController.removeListener(_markDraftChanged);
    _tileSizeController.removeListener(_markDraftChanged);
    _idController.dispose();
    _tileSizeController.dispose();
    super.dispose();
  }

  /// Discards an unsaved module form edit before session undo.
  bool cancelLocalDraft() {
    if (!_hasDraftChanges) return false;
    setState(() => _syncForm(_selectedModule(widget.document)));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final selected = _selectedModule(document);
    return PlatformModulesTab(
      moduleIdController: _idController,
      moduleTileSizeController: _tileSizeController,
      modules: document.tileData.platformModules,
      selectedModuleId: _selectedModuleId,
      selectedModule: selected,
      tileSlices: document.tileData.tileSlices,
      selectedTileSliceId: _selectedTileSliceId,
      selectedModuleSceneTool: _tool,
      workspaceRootPath: widget.controller.workspacePath,
      onUpsertModule: () => _upsert(document),
      onStartNewEmptyModule: _startNew,
      onRenameSelectedModule: () => _rename(document),
      onDuplicateSelectedModule: () => _duplicate(document),
      onToggleDeprecateSelectedModule: () => _toggleStatus(document),
      onSelectedModuleChanged: (id) => _selectModule(document, id),
      onSelectedTileSliceChanged: (id) =>
          setState(() => _selectedTileSliceId = id),
      onModuleSceneToolChanged: (tool) => setState(() => _tool = tool),
      onPaintCell: (gridX, gridY, sliceId) =>
          _paintCell(document, gridX: gridX, gridY: gridY, sliceId: sliceId),
      onEraseCell: (gridX, gridY) =>
          _eraseCell(document, gridX: gridX, gridY: gridY),
      onMoveCell: (sourceX, sourceY, targetX, targetY) => _moveCell(
        document,
        sourceX: sourceX,
        sourceY: sourceY,
        targetX: targetX,
        targetY: targetY,
      ),
      onDeleteModule: (id) => _deleteModule(document, id),
      onDeleteModuleCell: (id, index) =>
          _deleteCell(document, moduleId: id, cellIndex: index),
    );
  }

  void _initialize(PrefabV3Document document) {
    _selectedModuleId = document.tileData.platformModules.firstOrNull?.id;
    _selectedTileSliceId = document.tileData.tileSlices.firstOrNull?.id;
    _syncForm(_selectedModule(document));
  }

  void _reconcile(PrefabV3Document document) {
    if (_findModule(document, _selectedModuleId) == null) {
      _selectedModuleId = document.tileData.platformModules.firstOrNull?.id;
    }
    if (!document.tileData.tileSlices.any(
      (slice) => slice.id == _selectedTileSliceId,
    )) {
      _selectedTileSliceId = document.tileData.tileSlices.firstOrNull?.id;
    }
    _syncForm(_selectedModule(document));
  }

  void _selectModule(PrefabV3Document document, String? id) {
    if (_hasDraftChanges && id != _selectedModuleId) {
      _showMessage('Apply or undo the module form before selecting another.');
      return;
    }
    final module = _findModule(document, id);
    setState(() {
      _selectedModuleId = module?.id;
      _syncForm(module);
    });
  }

  void _startNew() {
    if (_hasDraftChanges) {
      _showMessage('Apply or undo the module form before starting a new one.');
      return;
    }
    setState(() {
      _selectedModuleId = null;
      _syncingDraft = true;
      try {
        _idController.clear();
        _tileSizeController.text = '16';
        _hasDraftChanges = false;
      } finally {
        _syncingDraft = false;
      }
    });
  }

  void _upsert(PrefabV3Document document) {
    final id = _validatedId();
    if (id == null) return;
    final tileSize = _validatedTileSize();
    if (tileSize == null) return;
    final current = _findModule(document, id);
    final operation = current == null
        ? PrefabV3CreateModuleOperation(
            id: id,
            status: TileModuleStatus.deprecated,
            tileSize: tileSize,
            cells: const <TileModuleCellDef>[],
          )
        : PrefabV3UpdateModuleOperation(
            moduleId: current.id,
            status: current.status,
            tileSize: tileSize,
            cells: current.cells,
          );
    if (current != null && current.tileSize == tileSize) {
      setState(() => _hasDraftChanges = false);
      return;
    }
    final next = _dispatch(document, operation);
    if (next == null) return;
    setState(() {
      _selectedModuleId = id;
      _syncForm(_findModule(next, id));
    });
  }

  void _rename(PrefabV3Document document) {
    final selected = _selectedModule(document);
    if (selected == null) {
      _showMessage('Select a module before renaming.');
      return;
    }
    final nextId = _validatedId();
    if (nextId == null) return;
    if (!_tileSizeMatches(selected)) {
      _showMessage('Apply or undo the tile-size edit before renaming.');
      return;
    }
    if (nextId == selected.id) {
      setState(() => _hasDraftChanges = false);
      return;
    }
    final next = _dispatch(
      document,
      PrefabV3RenameModuleOperation(moduleId: selected.id, nextId: nextId),
    );
    if (next == null) return;
    setState(() {
      _selectedModuleId = nextId;
      _syncForm(_findModule(next, nextId));
    });
  }

  void _duplicate(PrefabV3Document document) {
    final selected = _selectedModule(document);
    if (selected == null) {
      _showMessage('Select a module before duplicating.');
      return;
    }
    if (selected.cells.isEmpty) {
      _showMessage(
        'Add at least one tile cell before duplicating this module.',
      );
      return;
    }
    if (!_tileSizeMatches(selected)) {
      _showMessage('Apply or undo the tile-size edit before duplicating.');
      return;
    }
    final rawTarget = _idController.text;
    String? targetId;
    if (rawTarget.isNotEmpty && rawTarget != selected.id) {
      targetId = _validatedId();
      if (targetId == null) return;
    }
    final beforeIds = document.tileData.platformModules
        .map((module) => module.id)
        .toSet();
    final next = _dispatch(
      document,
      PrefabV3DuplicateModuleOperation(
        sourceModuleId: selected.id,
        targetId: targetId,
      ),
    );
    if (next == null) return;
    final createdId = next.tileData.platformModules
        .map((module) => module.id)
        .where((id) => !beforeIds.contains(id))
        .firstOrNull;
    setState(() {
      _selectedModuleId = createdId ?? selected.id;
      _syncForm(_selectedModule(next));
    });
  }

  void _toggleStatus(PrefabV3Document document) {
    final selected = _selectedModule(document);
    if (selected == null) {
      _showMessage('Select a module before changing its status.');
      return;
    }
    if (_idController.text != selected.id || !_tileSizeMatches(selected)) {
      _showMessage('Apply or undo the module form before changing status.');
      return;
    }
    final nextStatus = selected.status == TileModuleStatus.active
        ? TileModuleStatus.deprecated
        : TileModuleStatus.active;
    if (nextStatus == TileModuleStatus.active && selected.cells.isEmpty) {
      _showMessage(
        'Add at least one tile cell before reactivating the module.',
      );
      return;
    }
    final next = _updateModule(
      document,
      selected,
      status: nextStatus,
      cells: selected.cells,
    );
    if (next != null) setState(() => _syncForm(_selectedModule(next)));
  }

  void _paintCell(
    PrefabV3Document document, {
    required int gridX,
    required int gridY,
    required String sliceId,
  }) {
    final selected = _moduleForCellEdit(document);
    if (selected == null) return;
    final cells = PlatformModuleCellReducer.paint(
      selected.cells,
      gridX: gridX,
      gridY: gridY,
      sliceId: sliceId,
    );
    if (cells == null) return;
    _commitCells(document, selected, cells);
  }

  void _eraseCell(
    PrefabV3Document document, {
    required int gridX,
    required int gridY,
  }) {
    final selected = _moduleForCellEdit(document);
    if (selected == null) return;
    final cells = PlatformModuleCellReducer.erase(
      selected.cells,
      gridX: gridX,
      gridY: gridY,
    );
    if (cells == null) return;
    _commitCells(document, selected, cells);
  }

  void _moveCell(
    PrefabV3Document document, {
    required int sourceX,
    required int sourceY,
    required int targetX,
    required int targetY,
  }) {
    final selected = _moduleForCellEdit(document);
    if (selected == null) return;
    final cells = PlatformModuleCellReducer.move(
      selected.cells,
      sourceGridX: sourceX,
      sourceGridY: sourceY,
      targetGridX: targetX,
      targetGridY: targetY,
    );
    if (cells == null) return;
    _commitCells(document, selected, cells);
  }

  void _deleteCell(
    PrefabV3Document document, {
    required String moduleId,
    required int cellIndex,
  }) {
    final module = _findModule(document, moduleId);
    if (module == null || cellIndex < 0 || cellIndex >= module.cells.length) {
      return;
    }
    if (_hasDraftChanges) {
      _showMessage('Apply or undo the module form before editing cells.');
      return;
    }
    final cells = PlatformModuleCellReducer.deleteAt(module.cells, cellIndex);
    if (cells == null) return;
    _commitCells(document, module, cells);
  }

  void _commitCells(
    PrefabV3Document document,
    TileModuleDef module,
    List<TileModuleCellDef> cells,
  ) {
    final next = _updateModule(
      document,
      module,
      status: module.status,
      cells: cells,
    );
    if (next != null) setState(() => _syncForm(_selectedModule(next)));
  }

  TileModuleDef? _moduleForCellEdit(PrefabV3Document document) {
    if (_hasDraftChanges) {
      _showMessage('Apply or undo the module form before editing cells.');
      return null;
    }
    final selected = _selectedModule(document);
    if (selected == null) _showMessage('Select a module before editing cells.');
    return selected;
  }

  PrefabV3Document? _updateModule(
    PrefabV3Document document,
    TileModuleDef module, {
    required TileModuleStatus status,
    required Iterable<TileModuleCellDef> cells,
  }) => _dispatch(
    document,
    PrefabV3UpdateModuleOperation(
      moduleId: module.id,
      status: status,
      tileSize: module.tileSize,
      cells: cells,
    ),
  );

  Future<void> _deleteModule(PrefabV3Document document, String moduleId) async {
    if (_hasDraftChanges) {
      _showMessage('Apply or undo the module form before deleting.');
      return;
    }
    final references = document.data.prefabs
        .where(
          (prefab) => prefab.usesPlatformModule && prefab.moduleId == moduleId,
        )
        .map((prefab) => prefab.id)
        .toList(growable: false);
    if (references.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Cannot delete $moduleId'),
          content: Text(
            'Reassign or remove these prefab owners first: '
            '${references.join(', ')}.',
          ),
          actions: <Widget>[
            FilledButton(
              key: const ValueKey<String>('prefab_v3_module_delete_blocked'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete module $moduleId?'),
        content: const Text('This removes the unreferenced retained module.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey<String>('prefab_v3_module_delete_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete module'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final next = _dispatch(
      document,
      PrefabV3DeleteModuleOperation(moduleId: moduleId),
    );
    if (next == null) return;
    setState(() {
      if (_selectedModuleId == moduleId) {
        _selectedModuleId = next.tileData.platformModules.firstOrNull?.id;
      }
      _syncForm(_selectedModule(next));
    });
  }

  PrefabV3Document? _dispatch(
    PrefabV3Document document,
    PrefabV3CatalogOperation operation,
  ) {
    final beforeDocument = widget.controller.document;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3CatalogCommandKind,
        payload: <String, Object?>{
          'commit': PrefabV3CatalogCommit(
            before: PrefabV3CatalogSnapshot.fromDocument(document),
            operation: operation,
          ),
        },
      ),
    );
    final next = widget.controller.document;
    if (identical(next, beforeDocument) || next is! PrefabV3Document) {
      _showMessage(
        'Module change was rejected. Review validation diagnostics and retry '
        'from the current catalog state.',
      );
      return null;
    }
    return next;
  }

  String? _validatedId() {
    final id = _idController.text;
    if (id.isEmpty || id != id.trim()) {
      _showMessage(
        'Module ID must be non-empty with no surrounding whitespace.',
      );
      return null;
    }
    return id;
  }

  int? _validatedTileSize() {
    final tileSize = int.tryParse(_tileSizeController.text.trim());
    if (tileSize == null || tileSize <= 0) {
      _showMessage('Tile size must be a positive whole pixel count.');
      return null;
    }
    return tileSize;
  }

  bool _tileSizeMatches(TileModuleDef module) =>
      int.tryParse(_tileSizeController.text.trim()) == module.tileSize;

  TileModuleDef? _selectedModule(PrefabV3Document document) =>
      _findModule(document, _selectedModuleId);

  void _syncForm(TileModuleDef? module) {
    _syncingDraft = true;
    try {
      _idController.text = module?.id ?? '';
      _tileSizeController.text = (module?.tileSize ?? 16).toString();
      _hasDraftChanges = false;
    } finally {
      _syncingDraft = false;
    }
  }

  void _markDraftChanged() {
    if (_syncingDraft || _hasDraftChanges) return;
    setState(() => _hasDraftChanges = true);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

TileModuleDef? _findModule(PrefabV3Document document, String? moduleId) {
  if (moduleId == null) return null;
  for (final module in document.tileData.platformModules) {
    if (module.id == moduleId) return module;
  }
  return null;
}
