import 'package:flutter/material.dart';
import 'package:tool_ui/tool_ui.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';

import '../../../domain/authoring_types.dart';
import '../../../session/editor_session_controller.dart';
import '../../../training/training_field_domain_plugin.dart';
import '../chunkCreator/chunk_creator_location.dart';
import '../chunkCreator/v2/chunk_authoring_workspace.dart';
import '../shared/editor_page_local_draft_state.dart';
import '../shared/editor_page_navigation_state.dart';
import '../shared/terrain_polygon_scene_painter.dart';

/// Layout authoring only. Runtime training controls never enter this route.
class TrainingFieldPage extends StatefulWidget {
  const TrainingFieldPage({
    super.key,
    required this.controller,
    this.initialLocation,
    this.onShellStateChanged,
  });
  final EditorSessionController controller;
  final ChunkCreatorLocation? initialLocation;
  final VoidCallback? onShellStateChanged;
  @override
  State<TrainingFieldPage> createState() => _TrainingFieldPageState();
}

class _TrainingFieldPageState extends State<TrainingFieldPage>
    implements
        EditorPageNavigationState,
        EditorPageLocalDraftState,
        EditorPageSaveHandler,
        EditorPageReloadHandler,
        EditorPageSessionShortcutHandler {
  var _workspace = GlobalKey<ChunkAuthoringWorkspaceState>();
  var _spawns = GlobalKey<_SpawnInspectorState>();

  @override
  EditorPageLocation? get navigationLocation =>
      _workspace.currentState?.navigationLocation;
  @override
  bool get hasLocalDraftChanges =>
      (_workspace.currentState?.hasLocalDraftChanges ?? false) ||
      (_spawns.currentState?.dirty ?? false);
  @override
  bool get canSaveEditorPage =>
      !widget.controller.isLoading &&
      !widget.controller.isExporting &&
      (hasLocalDraftChanges || widget.controller.pendingChanges.hasChanges);
  @override
  Future<EditorPageSaveResult> saveEditorPage() async {
    if (!(_spawns.currentState?.commit() ?? true) ||
        !await (_workspace.currentState?.finalizeLocalEdits() ??
            Future.value(true))) {
      return EditorPageSaveResult.blocked;
    }
    await widget.controller.exportDirectWrite();
    return EditorPageSaveResult.fromSession(widget.controller);
  }

  @override
  bool get canReloadEditorPage =>
      !(_workspace.currentState?.hasActiveOperation ?? false) &&
      !widget.controller.isLoading &&
      !widget.controller.isExporting;
  @override
  Future<void> reloadEditorPage() async {
    await widget.controller.loadWorkspace();
    if (mounted && widget.controller.loadError == null) {
      setState(() {
        _workspace = GlobalKey<ChunkAuthoringWorkspaceState>();
        _spawns = GlobalKey<_SpawnInspectorState>();
      });
    }
  }

  @override
  bool get canHandleUndoSessionShortcut =>
      !(_spawns.currentState?.dirty ?? false) &&
      (_workspace.currentState?.canUndo ?? widget.controller.canUndo);
  @override
  bool get canHandleRedoSessionShortcut =>
      !(_spawns.currentState?.dirty ?? false) &&
      (_workspace.currentState?.canRedo ?? widget.controller.canRedo);
  @override
  bool handleUndoSessionShortcut() =>
      canHandleUndoSessionShortcut &&
      (_workspace.currentState?.handleUndoShortcut() ?? false);
  @override
  bool handleRedoSessionShortcut() =>
      canHandleRedoSessionShortcut &&
      (_workspace.currentState?.handleRedoShortcut() ?? false);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.controller.document == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.controller.isLoading) {
          widget.controller.loadWorkspace();
        }
      });
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.controller.document;
    if (document is! TrainingFieldDocument) {
      return const Center(child: Text('Loading Training Field…'));
    }
    return ChunkAuthoringWorkspace(
      key: _workspace,
      controller: widget.controller,
      initialLocation: widget.initialLocation,
      fixedLayout: true,
      onDraftStateChanged: widget.onShellStateChanged,
      layoutInspector: _SpawnInspector(
        key: _spawns,
        document: document,
        controller: widget.controller,
        onChanged: widget.onShellStateChanged,
      ),
      layoutOverlayBuilder: (chunk, transform) => IgnorePointer(
        child: CustomPaint(
          painter: _SpawnPainter(document.source, chunk.chunkKey, transform),
        ),
      ),
    );
  }
}

class _SpawnInspector extends StatefulWidget {
  const _SpawnInspector({
    super.key,
    required this.document,
    required this.controller,
    this.onChanged,
  });
  final TrainingFieldDocument document;
  final EditorSessionController controller;
  final VoidCallback? onChanged;
  @override
  State<_SpawnInspector> createState() => _SpawnInspectorState();
}

class _SpawnInspectorState extends State<_SpawnInspector> {
  final _form = GlobalKey<FormState>();
  final _fields = List.generate(4, (_) => TextEditingController());
  int _enemyChunk = 1;
  bool dirty = false;
  bool _committing = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final source = widget.document.source;
    final values = [
      source.playerStartX,
      source.playerStartY,
      source.enemySpawnX,
      source.enemySpawnY,
    ];
    for (var i = 0; i < 4; i++) {
      _fields[i].text = '${values[i]}';
    }
    _enemyChunk = source.enemyChunkIndex;
    dirty = false;
  }

  @override
  void didUpdateWidget(covariant _SpawnInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_committing &&
        !identical(oldWidget.document, widget.document) &&
        !dirty) {
      _load();
    }
  }

  bool commit() {
    if (!dirty) return true;
    if (!(_form.currentState?.validate() ?? false)) return false;
    _committing = true;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: TrainingFieldDomainPlugin.setSpawns,
        payload: {
          'playerX': int.parse(_fields[0].text),
          'playerY': int.parse(_fields[1].text),
          'enemyX': int.parse(_fields[2].text),
          'enemyY': int.parse(_fields[3].text),
          'enemyChunk': _enemyChunk,
        },
      ),
    );
    _committing = false;
    dirty = false;
    widget.onChanged?.call();
    return true;
  }

  @override
  Widget build(BuildContext context) => ToolPanelCard(
    title: 'Spawn positions',
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Player start · Chunk 1'),
          _position(0),
          const SizedBox(height: 16),
          const Text('Enemy spawn'),
          DropdownButton<int>(
            value: _enemyChunk,
            items: const [
              DropdownMenuItem(value: 0, child: Text('Chunk 1')),
              DropdownMenuItem(value: 1, child: Text('Chunk 2')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _enemyChunk = value;
                  dirty = true;
                });
                commit();
              }
            },
          ),
          _position(2),
          const SizedBox(height: 8),
          const Text(
            'Positions mark the terrain contact point. Save then Build to update the game.',
          ),
        ],
      ),
    ),
  );

  Widget _position(int start) => Row(
    children: [
      for (var i = start; i < start + 2; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextFormField(
              key: ValueKey('training-spawn-$i'),
              controller: _fields[i],
              decoration: InputDecoration(labelText: i.isEven ? 'X' : 'Y'),
              keyboardType: TextInputType.number,
              onChanged: (_) {
                dirty = true;
                widget.onChanged?.call();
              },
              onEditingComplete: commit,
              validator: (text) {
                final value = int.tryParse(text ?? '');
                final min = i.isEven ? 1 : 0, max = i.isEven ? 599 : 270;
                return value == null || value < min || value > max
                    ? '$min–$max whole pixels'
                    : null;
              },
            ),
          ),
        ),
    ],
  );
  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }
}

class _SpawnPainter extends CustomPainter {
  const _SpawnPainter(this.source, this.chunkKey, this.transform);
  final TrainingFieldSource source;
  final String chunkKey;
  final TerrainPolygonViewportTransform transform;
  @override
  void paint(Canvas canvas, Size size) {
    void marker(int x, int y, Color color, String label) {
      final point =
          transform.origin + Offset(x * transform.zoom, y * transform.zoom);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2;
      canvas.drawLine(
        point - const Offset(7, 0),
        point + const Offset(7, 0),
        paint,
      );
      canvas.drawLine(
        point - const Offset(0, 14),
        point + const Offset(0, 4),
        paint,
      );
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            backgroundColor: Colors.black87,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, point + const Offset(10, -20));
    }

    if (chunkKey == 'training_field_1') {
      marker(
        source.playerStartX,
        source.playerStartY,
        Colors.lightBlueAccent,
        'Player start',
      );
    }
    if (chunkKey == 'training_field_${source.enemyChunkIndex + 1}') {
      marker(
        source.enemySpawnX,
        source.enemySpawnY,
        Colors.orangeAccent,
        'Enemy spawn',
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpawnPainter old) =>
      old.source != source ||
      old.chunkKey != chunkKey ||
      old.transform != transform;
}
