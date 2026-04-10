import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../chunks/chunk_domain_models.dart';
import '../../../../prefabs/models/models.dart';
import '../../prefabCreator/shared/prefab_overlay_interaction.dart';
import '../../prefabCreator/shared/prefab_scene_values.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_scene_viewport_frame.dart';
import '../../shared/editor_viewport_grid_painter.dart';
import '../../shared/editor_zoom_controls.dart';
import '../../shared/scene_input_utils.dart';
import 'chunk_scene_ground.dart';

enum ChunkSceneTool { place, select, erase }

enum ChunkScenePlaceMode { prefab, enemyMarker }

extension ChunkSceneToolLabel on ChunkSceneTool {
  String get label {
    switch (this) {
      case ChunkSceneTool.place:
        return 'Place';
      case ChunkSceneTool.select:
        return 'Select';
      case ChunkSceneTool.erase:
        return 'Erase';
    }
  }
}

class ChunkSceneView extends StatefulWidget {
  const ChunkSceneView({
    super.key,
    required this.workspaceRootPath,
    required this.chunk,
    required this.prefabData,
    required this.runtimeGridSnap,
    required this.tool,
    required this.placeMode,
    required this.placeSnapToGrid,
    required this.selectedPalettePrefabKey,
    required this.selectedPlacementKey,
    required this.selectedEnemyMarkerId,
    required this.selectedMarkerKey,
    required this.onToolChanged,
    required this.onPlacePrefab,
    required this.onSelectPlacement,
    required this.onMovePlacement,
    required this.onCommitPlacementMove,
    required this.onRemovePlacement,
    required this.onPlaceMarker,
    required this.onSelectMarker,
    required this.onMoveMarker,
    required this.onCommitMarkerMove,
    required this.onRemoveMarker,
    this.showParallaxPreview = true,
  });

  final String workspaceRootPath;
  final LevelChunkDef chunk;
  final PrefabData prefabData;
  final double runtimeGridSnap;
  final ChunkSceneTool tool;
  final ChunkScenePlaceMode placeMode;
  final bool placeSnapToGrid;
  final String? selectedPalettePrefabKey;
  final String? selectedPlacementKey;
  final String selectedEnemyMarkerId;
  final String? selectedMarkerKey;
  final ValueChanged<ChunkSceneTool> onToolChanged;
  final void Function(int x, int y) onPlacePrefab;
  final ValueChanged<String?> onSelectPlacement;
  final void Function(String selectionKey, int x, int y) onMovePlacement;
  final VoidCallback onCommitPlacementMove;
  final ValueChanged<String> onRemovePlacement;
  final void Function(int x, int y) onPlaceMarker;
  final ValueChanged<String?> onSelectMarker;
  final void Function(String selectionKey, int x, int y) onMoveMarker;
  final VoidCallback onCommitMarkerMove;
  final ValueChanged<String> onRemoveMarker;
  final bool showParallaxPreview;

  @override
  State<ChunkSceneView> createState() => _ChunkSceneViewState();
}

/// Compact, non-interactive chunk thumbnail used by the chunk list.
///
/// This intentionally reuses the same render data and painter as the main chunk
/// composer so ground bands, gaps, obstacles, and platform modules stay
/// visually consistent with the editor scene.
class ChunkScenePreviewTile extends StatefulWidget {
  const ChunkScenePreviewTile({
    super.key,
    required this.imageCache,
    required this.workspaceRootPath,
    required this.chunk,
    required this.prefabData,
    required this.runtimeGridSnap,
    this.width = double.infinity,
    this.height = 92,
  });

  final EditorUiImageCache imageCache;
  final String workspaceRootPath;
  final LevelChunkDef chunk;
  final PrefabData prefabData;
  final double runtimeGridSnap;
  final double width;
  final double height;

  @override
  State<ChunkScenePreviewTile> createState() => _ChunkScenePreviewTileState();
}

class _ChunkScenePreviewTileState extends State<ChunkScenePreviewTile> {
  final Map<String, ui.Rect> _groundMaterialSrcRectsByAbsolutePath =
      <String, ui.Rect>{};

  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _refreshAssets();
  }

  @override
  void didUpdateWidget(covariant ChunkScenePreviewTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceRootPath != widget.workspaceRootPath ||
        oldWidget.chunk != widget.chunk ||
        oldWidget.prefabData != widget.prefabData ||
        oldWidget.imageCache != widget.imageCache) {
      _refreshAssets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final renderPlacements = _buildChunkRenderPlacements(
      chunk: widget.chunk,
      prefabData: widget.prefabData,
    );
    final groundMaterial = resolveChunkGroundMaterialSpec(widget.chunk.levelId);
    final groundMaterialAbsolutePath = _absoluteImagePath(
      groundMaterial.sourceImagePath,
    );
    final groundMaterialSrcRect =
        _groundMaterialSrcRectsByAbsolutePath[groundMaterialAbsolutePath];
    final groundLayout = buildChunkGroundLayoutWithFillDepth(
      widget.chunk,
      fillDepth:
          groundMaterialSrcRect?.height ??
          groundMaterial.fallbackMaterialHeight,
    );

    return SizedBox(
      width: widget.width.isFinite ? widget.width : double.infinity,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final previewWidth = widget.width.isFinite
              ? widget.width
              : (constraints.maxWidth.isFinite ? constraints.maxWidth : 240.0);
          final previewSize = Size(
            math.max(1.0, previewWidth),
            math.max(1.0, widget.height),
          );

          return DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF101820),
              border: Border.all(color: const Color(0xFF29404F)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CustomPaint(
                painter: _ChunkScenePainter(
                  workspaceRootPath: widget.workspaceRootPath,
                  imageCache: widget.imageCache,
                  loadedImageCount: widget.imageCache.loadedImageCount,
                  geometry: _ChunkSceneGeometry.preview(
                    chunk: widget.chunk,
                    runtimeGridSnap: widget.runtimeGridSnap,
                    renderPlacements: renderPlacements,
                    renderMarkers: const <_ChunkRenderMarker>[],
                    viewportSize: previewSize,
                  ),
                  chunk: widget.chunk,
                  showParallaxPreview: false,
                  showPixelGrid: false,
                  showChunkBounds: false,
                  showMarkers: false,
                  clipSceneToChunkBounds: true,
                  parallaxPreview: const ChunkParallaxPreviewSpec(),
                  groundLayout: groundLayout,
                  groundMaterial: groundMaterial,
                  groundMaterialSrcRect: groundMaterialSrcRect,
                  renderPlacements: renderPlacements,
                  renderMarkers: const <_ChunkRenderMarker>[],
                  selectedPlacement: null,
                  selectedMarker: null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _refreshAssets() {
    final loadGeneration = ++_loadGeneration;
    final groundMaterial = resolveChunkGroundMaterialSpec(widget.chunk.levelId);
    final groundMaterialAbsolutePath = _absoluteImagePath(
      groundMaterial.sourceImagePath,
    );
    final requiredPaths = <String>{groundMaterialAbsolutePath};
    for (final placement in _buildChunkRenderPlacements(
      chunk: widget.chunk,
      prefabData: widget.prefabData,
    )) {
      for (final sprite in placement.sprites) {
        final sourceImagePath = sprite.slice?.sourceImagePath.trim() ?? '';
        if (sourceImagePath.isEmpty) {
          continue;
        }
        requiredPaths.add(_absoluteImagePath(sourceImagePath));
      }
    }

    unawaited(
      _loadAssets(
        loadGeneration: loadGeneration,
        absolutePaths: requiredPaths.toList(growable: false),
        groundMaterialAbsolutePath: groundMaterialAbsolutePath,
        fallbackMaterialHeight: groundMaterial.fallbackMaterialHeight,
      ),
    );
  }

  Future<void> _loadAssets({
    required int loadGeneration,
    required List<String> absolutePaths,
    required String groundMaterialAbsolutePath,
    required double fallbackMaterialHeight,
  }) async {
    await Future.wait(
      absolutePaths.map(
        (absolutePath) => widget.imageCache.ensureLoaded(absolutePath),
      ),
    );
    if (!mounted || loadGeneration != _loadGeneration) {
      return;
    }

    final groundImage = widget.imageCache.imageFor(groundMaterialAbsolutePath);
    if (groundImage != null &&
        !_groundMaterialSrcRectsByAbsolutePath.containsKey(
          groundMaterialAbsolutePath,
        )) {
      final srcRect = await detectGroundMaterialSourceRect(
        groundImage,
        fallbackMaterialHeight: fallbackMaterialHeight,
      );
      if (!mounted || loadGeneration != _loadGeneration) {
        return;
      }
      _groundMaterialSrcRectsByAbsolutePath[groundMaterialAbsolutePath] =
          srcRect;
    }
    setState(() {});
  }

  String _absoluteImagePath(String relativePath) {
    return p.normalize(p.join(widget.workspaceRootPath, relativePath));
  }
}

class _ChunkSceneViewState extends State<ChunkSceneView> {
  static const double _minZoom = 0.25;
  static const double _maxZoom = 6.0;
  static const double _zoomStep = 0.1;
  static const double _canvasMargin = 96.0;

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final EditorUiImageCache _imageCache = EditorUiImageCache();
  final Map<String, ui.Rect> _groundMaterialSrcRectsByAbsolutePath =
      <String, ui.Rect>{};
  final Set<String> _groundMaterialDetectionInFlight = <String>{};

  double _zoom = 1.75;
  bool _ctrlPanActive = false;
  int? _activePointer;
  _ChunkPlacementDragState? _dragState;
  _ChunkMarkerDragState? _markerDragState;

  @override
  void initState() {
    super.initState();
    _ensureAllSceneImagesLoaded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      EditorSceneViewUtils.scheduleViewportCentering(
        context: context,
        horizontal: _horizontalScrollController,
        vertical: _verticalScrollController,
      );
    });
  }

  @override
  void didUpdateWidget(covariant ChunkSceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceRootPath != widget.workspaceRootPath ||
        oldWidget.chunk != widget.chunk ||
        oldWidget.prefabData != widget.prefabData) {
      _ensureAllSceneImagesLoaded();
    }
    final dragState = _dragState;
    final selectedPlacementKey = widget.selectedPlacementKey;
    if (dragState != null &&
        selectedPlacementKey != null &&
        selectedPlacementKey.isNotEmpty &&
        selectedPlacementKey != dragState.selectionKey) {
      _dragState = dragState.copyWith(selectionKey: selectedPlacementKey);
    }
    final markerDragState = _markerDragState;
    final selectedMarkerKey = widget.selectedMarkerKey;
    if (markerDragState != null &&
        selectedMarkerKey != null &&
        selectedMarkerKey.isNotEmpty &&
        selectedMarkerKey != markerDragState.selectionKey) {
      _markerDragState = markerDragState.copyWith(
        selectionKey: selectedMarkerKey,
      );
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _imageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renderPlacements = _buildRenderPlacements();
    final renderMarkers = _buildRenderMarkers();
    final selectedPlacement = _resolveSelectedPlacement(renderPlacements);
    final selectedMarker = _resolveSelectedMarker(renderMarkers);
    final groundMaterial = resolveChunkGroundMaterialSpec(widget.chunk.levelId);
    final parallaxPreview = resolveChunkParallaxPreviewSpec(
      widget.chunk.levelId,
    );
    final groundMaterialAbsolutePath = _absoluteImagePath(
      groundMaterial.sourceImagePath,
    );
    final groundMaterialSrcRect =
        _groundMaterialSrcRectsByAbsolutePath[groundMaterialAbsolutePath];
    final groundLayout = buildChunkGroundLayoutWithFillDepth(
      widget.chunk,
      fillDepth:
          groundMaterialSrcRect?.height ??
          groundMaterial.fallbackMaterialHeight,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 960.0;
        final viewportHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 620.0;
        final geometry = _ChunkSceneGeometry(
          chunk: widget.chunk,
          runtimeGridSnap: widget.runtimeGridSnap,
          renderPlacements: renderPlacements,
          renderMarkers: renderMarkers,
          viewportSize: Size(
            math.max(1.0, viewportWidth),
            math.max(1.0, viewportHeight),
          ),
          zoom: _zoom,
          canvasMargin: _canvasMargin,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildControls(context),
            const SizedBox(height: 8),
            Expanded(
              child: EditorSceneViewportFrame(
                width: viewportWidth,
                height: viewportHeight,
                child: _buildScrollableCanvas(
                  geometry: geometry,
                  parallaxPreview: parallaxPreview,
                  groundLayout: groundLayout,
                  groundMaterial: groundMaterial,
                  groundMaterialSrcRect: groundMaterialSrcRect,
                  renderPlacements: renderPlacements,
                  renderMarkers: renderMarkers,
                  selectedPlacement: selectedPlacement,
                  selectedMarker: selectedMarker,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls(BuildContext context) {
    final paletteLabel = widget.placeMode == ChunkScenePlaceMode.prefab
        ? (widget.selectedPalettePrefabKey == null
              ? 'No prefab selected'
              : 'Palette: ${widget.selectedPalettePrefabKey}')
        : 'Enemy: ${widget.selectedEnemyMarkerId}';
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        EditorZoomControls(
          value: _zoom,
          min: _minZoom,
          max: _maxZoom,
          step: _zoomStep,
          onChanged: _setZoom,
        ),
        for (final tool in ChunkSceneTool.values)
          ChoiceChip(
            key: ValueKey<String>('chunk_scene_tool_${tool.name}'),
            label: Text(tool.label),
            selected: widget.tool == tool,
            onSelected: (_) {
              widget.onToolChanged(tool);
            },
          ),
        Chip(
          avatar: const Icon(Icons.layers_outlined, size: 16),
          label: Text(paletteLabel),
        ),
      ],
    );
  }

  Widget _buildScrollableCanvas({
    required _ChunkSceneGeometry geometry,
    required ChunkParallaxPreviewSpec parallaxPreview,
    required ChunkGroundLayout groundLayout,
    required ChunkGroundMaterialSpec groundMaterial,
    required ui.Rect? groundMaterialSrcRect,
    required List<_ChunkRenderPlacement> renderPlacements,
    required List<_ChunkRenderMarker> renderMarkers,
    required _ChunkRenderPlacement? selectedPlacement,
    required _ChunkRenderMarker? selectedMarker,
  }) {
    final canvas = SizedBox(
      width: geometry.canvasSize.width,
      height: geometry.canvasSize.height,
      child: Listener(
        key: const ValueKey<String>('chunk_scene_canvas'),
        onPointerDown: (event) {
          _onPointerDown(
            event,
            geometry: geometry,
            renderPlacements: renderPlacements,
            renderMarkers: renderMarkers,
          );
        },
        onPointerMove: (event) {
          _onPointerMove(event, geometry: geometry);
        },
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        onPointerSignal: _onPointerSignal,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _ChunkScenePainter(
                workspaceRootPath: widget.workspaceRootPath,
                imageCache: _imageCache,
                loadedImageCount: _imageCache.loadedImageCount,
                geometry: geometry,
                chunk: widget.chunk,
                showParallaxPreview: widget.showParallaxPreview,
                parallaxPreview: parallaxPreview,
                groundLayout: groundLayout,
                groundMaterial: groundMaterial,
                groundMaterialSrcRect: groundMaterialSrcRect,
                renderPlacements: renderPlacements,
                renderMarkers: renderMarkers,
                selectedPlacement: selectedPlacement,
                selectedMarker: selectedMarker,
              ),
            ),
            IgnorePointer(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xCC0F1720),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x334D6A82)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        'viewport ${widget.chunk.width} x ${widget.chunk.height}   '
                        'floorY=${widget.chunk.groundProfile.topY}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        key: const ValueKey<String>('chunk_scene_vertical_scroll'),
        controller: _verticalScrollController,
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          key: const ValueKey<String>('chunk_scene_horizontal_scroll'),
          controller: _horizontalScrollController,
          scrollDirection: Axis.horizontal,
          child: canvas,
        ),
      ),
    );
  }

  void _onPointerDown(
    PointerDownEvent event, {
    required _ChunkSceneGeometry geometry,
    required List<_ChunkRenderPlacement> renderPlacements,
    required List<_ChunkRenderMarker> renderMarkers,
  }) {
    if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
      return;
    }
    _activePointer = event.pointer;
    _ctrlPanActive = SceneInputUtils.shouldPanWithPrimaryDrag(event.buttons);
    if (_ctrlPanActive) {
      return;
    }

    final hit = geometry.hitTestPlacement(
      event.localPosition,
      renderPlacements,
    );
    final markerHit = geometry.hitTestMarker(
      event.localPosition,
      renderMarkers,
    );
    switch (widget.tool) {
      case ChunkSceneTool.place:
        if (widget.placeMode == ChunkScenePlaceMode.prefab) {
          if (widget.selectedPalettePrefabKey == null) {
            if (hit != null) {
              widget.onSelectPlacement(hit.selectionKey);
            }
            return;
          }
          final snapped = geometry.snappedWorldPoint(
            event.localPosition,
            widget.placeSnapToGrid ? widget.runtimeGridSnap : 0,
          );
          if (snapped == null) {
            return;
          }
          widget.onPlacePrefab(snapped.dx.round(), snapped.dy.round());
          return;
        }
        final snapped = geometry.snappedWorldPoint(
          event.localPosition,
          widget.runtimeGridSnap,
        );
        if (snapped == null) {
          return;
        }
        widget.onPlaceMarker(snapped.dx.round(), snapped.dy.round());
        return;
      case ChunkSceneTool.select:
        if (widget.placeMode == ChunkScenePlaceMode.prefab) {
          if (hit == null) {
            widget.onSelectPlacement(null);
            return;
          }
          widget.onSelectPlacement(hit.selectionKey);
          final pointerWorld = geometry.worldFromLocal(event.localPosition);
          if (pointerWorld == null) {
            return;
          }
          setState(() {
            _dragState = _ChunkPlacementDragState(
              pointer: event.pointer,
              selectionKey: hit.selectionKey,
              resolvedPrefabRef: hit.placement.resolvedPrefabRef,
              snapToGrid: hit.placement.snapToGrid,
              grabOffsetWorld:
                  pointerWorld -
                  Offset(
                    hit.placement.x.toDouble(),
                    hit.placement.y.toDouble(),
                  ),
              lastAppliedX: hit.placement.x,
              lastAppliedY: hit.placement.y,
            );
          });
          return;
        }
        if (markerHit == null) {
          widget.onSelectMarker(null);
          return;
        }
        widget.onSelectMarker(markerHit.selectionKey);
        final pointerWorld = geometry.worldFromLocal(event.localPosition);
        if (pointerWorld == null) {
          return;
        }
        setState(() {
          _markerDragState = _ChunkMarkerDragState(
            pointer: event.pointer,
            selectionKey: markerHit.selectionKey,
            grabOffsetWorld:
                pointerWorld -
                Offset(
                  markerHit.marker.x.toDouble(),
                  markerHit.marker.y.toDouble(),
                ),
            lastAppliedX: markerHit.marker.x,
            lastAppliedY: markerHit.marker.y,
          );
        });
        return;
      case ChunkSceneTool.erase:
        if (widget.placeMode == ChunkScenePlaceMode.prefab) {
          if (hit == null) {
            widget.onSelectPlacement(null);
            return;
          }
          widget.onRemovePlacement(hit.selectionKey);
          widget.onSelectPlacement(null);
          return;
        }
        if (markerHit == null) {
          widget.onSelectMarker(null);
          return;
        }
        widget.onRemoveMarker(markerHit.selectionKey);
        widget.onSelectMarker(null);
        return;
    }
  }

  void _onPointerMove(
    PointerMoveEvent event, {
    required _ChunkSceneGeometry geometry,
  }) {
    if (_activePointer != event.pointer) {
      return;
    }
    if (_ctrlPanActive) {
      if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
        _resetPointerState(commitMove: false);
        return;
      }
      SceneInputUtils.panScrollControllers(
        horizontal: _horizontalScrollController,
        vertical: _verticalScrollController,
        pointerDelta: event.delta,
      );
      return;
    }
    if (widget.tool != ChunkSceneTool.select) {
      return;
    }
    if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
      _resetPointerState(commitMove: true);
      return;
    }

    if (widget.placeMode == ChunkScenePlaceMode.prefab) {
      final dragState = _dragState;
      if (dragState == null) {
        return;
      }
      final pointerWorld = geometry.worldFromLocal(event.localPosition);
      if (pointerWorld == null) {
        return;
      }
      final candidateAnchor = pointerWorld - dragState.grabOffsetWorld;
      final snapped = geometry.snapWorldPoint(
        candidateAnchor,
        dragState.snapToGrid ? widget.runtimeGridSnap : 0,
      );
      final snappedX = snapped.dx.round();
      final snappedY = snapped.dy.round();
      if (snappedX == dragState.lastAppliedX &&
          snappedY == dragState.lastAppliedY) {
        return;
      }
      widget.onMovePlacement(dragState.selectionKey, snappedX, snappedY);
      setState(() {
        _dragState = dragState.copyWith(
          lastAppliedX: snappedX,
          lastAppliedY: snappedY,
        );
      });
      return;
    }

    final markerDragState = _markerDragState;
    if (markerDragState == null) {
      return;
    }
    final pointerWorld = geometry.worldFromLocal(event.localPosition);
    if (pointerWorld == null) {
      return;
    }
    final candidateAnchor = pointerWorld - markerDragState.grabOffsetWorld;
    final snapped = geometry.snapWorldPoint(
      candidateAnchor,
      widget.runtimeGridSnap,
    );
    final snappedX = snapped.dx.round();
    final snappedY = snapped.dy.round();
    if (snappedX == markerDragState.lastAppliedX &&
        snappedY == markerDragState.lastAppliedY) {
      return;
    }
    widget.onMoveMarker(markerDragState.selectionKey, snappedX, snappedY);
    setState(() {
      _markerDragState = markerDragState.copyWith(
        lastAppliedX: snappedX,
        lastAppliedY: snappedY,
      );
    });
  }

  void _onPointerEnd(PointerEvent _) {
    _resetPointerState(commitMove: true);
  }

  void _resetPointerState({required bool commitMove}) {
    final hadDrag = _dragState != null;
    final hadMarkerDrag = _markerDragState != null;
    _ctrlPanActive = false;
    _activePointer = null;
    _dragState = null;
    _markerDragState = null;
    if (commitMove && hadDrag) {
      widget.onCommitPlacementMove();
    }
    if (commitMove && hadMarkerDrag) {
      widget.onCommitMarkerMove();
    }
    if (hadDrag || hadMarkerDrag) {
      setState(() {});
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    final signedSteps = SceneInputUtils.signedZoomStepsFromCtrlScroll(event);
    if (signedSteps == 0) {
      return;
    }
    _setZoom(_zoom + (signedSteps * _zoomStep));
  }

  void _setZoom(double value) {
    final next = EditorSceneViewUtils.snapZoom(
      value: value,
      min: _minZoom,
      max: _maxZoom,
      step: _zoomStep,
    );
    if (EditorSceneViewUtils.zoomValuesEqual(next, _zoom)) {
      return;
    }
    setState(() {
      _zoom = next;
    });
  }

  List<_ChunkRenderPlacement> _buildRenderPlacements() {
    return _buildChunkRenderPlacements(
      chunk: widget.chunk,
      prefabData: widget.prefabData,
    );
  }

  List<_ChunkRenderMarker> _buildRenderMarkers() {
    return _buildChunkRenderMarkers(widget.chunk);
  }

  _ChunkRenderPlacement? _resolveSelectedPlacement(
    List<_ChunkRenderPlacement> renderPlacements,
  ) {
    final selectedPlacementKey = widget.selectedPlacementKey;
    if (selectedPlacementKey == null || selectedPlacementKey.isEmpty) {
      return null;
    }
    for (final placement in renderPlacements) {
      if (placement.selectionKey == selectedPlacementKey) {
        return placement;
      }
    }
    return null;
  }

  _ChunkRenderMarker? _resolveSelectedMarker(
    List<_ChunkRenderMarker> renderMarkers,
  ) {
    final selectedMarkerKey = widget.selectedMarkerKey;
    if (selectedMarkerKey == null || selectedMarkerKey.isEmpty) {
      return null;
    }
    for (final marker in renderMarkers) {
      if (marker.selectionKey == selectedMarkerKey) {
        return marker;
      }
    }
    return null;
  }

  void _ensureAllSceneImagesLoaded() {
    final uniquePaths = <String>{};
    final groundMaterial = resolveChunkGroundMaterialSpec(widget.chunk.levelId);
    final parallaxPreview = resolveChunkParallaxPreviewSpec(
      widget.chunk.levelId,
    );
    uniquePaths.add(groundMaterial.sourceImagePath);
    uniquePaths.addAll(
      parallaxPreview.backgroundLayers.map((layer) => layer.assetPath),
    );
    uniquePaths.addAll(
      parallaxPreview.foregroundLayers.map((layer) => layer.assetPath),
    );
    for (final placement in _buildRenderPlacements()) {
      for (final sprite in placement.sprites) {
        final sourceImagePath = sprite.slice?.sourceImagePath.trim() ?? '';
        if (sourceImagePath.isEmpty) {
          continue;
        }
        uniquePaths.add(sourceImagePath);
      }
    }
    for (final relativePath in uniquePaths) {
      _ensureImageLoaded(
        relativePath,
        detectGroundMaterial: relativePath == groundMaterial.sourceImagePath,
        fallbackMaterialHeight: groundMaterial.fallbackMaterialHeight,
      );
    }
  }

  void _ensureImageLoaded(
    String sourceImagePath, {
    bool detectGroundMaterial = false,
    double fallbackMaterialHeight = 16.0,
  }) {
    final absolutePath = _absoluteImagePath(sourceImagePath);
    () async {
      final image = await _imageCache.ensureLoaded(absolutePath);
      if (!mounted || image == null) {
        return;
      }
      if (detectGroundMaterial &&
          !_groundMaterialSrcRectsByAbsolutePath.containsKey(absolutePath) &&
          _groundMaterialDetectionInFlight.add(absolutePath)) {
        final srcRect = await detectGroundMaterialSourceRect(
          image,
          fallbackMaterialHeight: fallbackMaterialHeight,
        );
        _groundMaterialDetectionInFlight.remove(absolutePath);
        if (!mounted) {
          return;
        }
        _groundMaterialSrcRectsByAbsolutePath[absolutePath] = srcRect;
      }
      setState(() {});
    }();
  }

  String _absoluteImagePath(String relativePath) {
    return p.normalize(p.join(widget.workspaceRootPath, relativePath));
  }
}

List<_ChunkRenderPlacement> _buildChunkRenderPlacements({
  required LevelChunkDef chunk,
  required PrefabData prefabData,
}) {
  final prefabByKey = <String, PrefabDef>{
    for (final prefab in prefabData.prefabs)
      if (prefab.prefabKey.isNotEmpty) prefab.prefabKey: prefab,
  };
  final prefabById = <String, PrefabDef>{
    for (final prefab in prefabData.prefabs)
      if (prefab.id.isNotEmpty) prefab.id: prefab,
  };
  final prefabSliceById = <String, AtlasSliceDef>{
    for (final slice in prefabData.prefabSlices)
      if (slice.id.isNotEmpty) slice.id: slice,
  };
  final tileSliceById = <String, AtlasSliceDef>{
    for (final slice in prefabData.tileSlices)
      if (slice.id.isNotEmpty) slice.id: slice,
  };
  final moduleById = <String, TileModuleDef>{
    for (final module in prefabData.platformModules)
      if (module.id.isNotEmpty) module.id: module,
  };

  final selections = buildChunkPlacedPrefabSelections(chunk.prefabs);
  return selections
      .map((selection) {
        final placement = selection.prefab;
        final resolvedPrefab =
            prefabByKey[placement.prefabKey] ?? prefabById[placement.prefabId];
        return _ChunkRenderPlacement.fromPlacement(
          selectionKey: selection.selectionKey,
          placement: placement,
          prefab: resolvedPrefab,
          prefabSliceById: prefabSliceById,
          tileSliceById: tileSliceById,
          moduleById: moduleById,
        );
      })
      .toList(growable: false)
    ..sort(_compareRenderPlacements);
}

List<_ChunkRenderMarker> _buildChunkRenderMarkers(LevelChunkDef chunk) {
  final selections = buildChunkPlacedMarkerSelections(chunk.markers);
  return selections
      .map(
        (selection) => _ChunkRenderMarker(
          selectionKey: selection.selectionKey,
          marker: selection.marker,
        ),
      )
      .toList(growable: false)
    ..sort(_compareRenderMarkers);
}

class _ChunkPlacementDragState {
  const _ChunkPlacementDragState({
    required this.pointer,
    required this.selectionKey,
    required this.resolvedPrefabRef,
    required this.snapToGrid,
    required this.grabOffsetWorld,
    required this.lastAppliedX,
    required this.lastAppliedY,
  });

  final int pointer;
  final String selectionKey;
  final String resolvedPrefabRef;
  final bool snapToGrid;
  final Offset grabOffsetWorld;
  final int lastAppliedX;
  final int lastAppliedY;

  _ChunkPlacementDragState copyWith({
    String? selectionKey,
    int? lastAppliedX,
    int? lastAppliedY,
  }) {
    return _ChunkPlacementDragState(
      pointer: pointer,
      selectionKey: selectionKey ?? this.selectionKey,
      resolvedPrefabRef: resolvedPrefabRef,
      snapToGrid: snapToGrid,
      grabOffsetWorld: grabOffsetWorld,
      lastAppliedX: lastAppliedX ?? this.lastAppliedX,
      lastAppliedY: lastAppliedY ?? this.lastAppliedY,
    );
  }
}

class _ChunkMarkerDragState {
  const _ChunkMarkerDragState({
    required this.pointer,
    required this.selectionKey,
    required this.grabOffsetWorld,
    required this.lastAppliedX,
    required this.lastAppliedY,
  });

  final int pointer;
  final String selectionKey;
  final Offset grabOffsetWorld;
  final int lastAppliedX;
  final int lastAppliedY;

  _ChunkMarkerDragState copyWith({
    String? selectionKey,
    int? lastAppliedX,
    int? lastAppliedY,
  }) {
    return _ChunkMarkerDragState(
      pointer: pointer,
      selectionKey: selectionKey ?? this.selectionKey,
      grabOffsetWorld: grabOffsetWorld,
      lastAppliedX: lastAppliedX ?? this.lastAppliedX,
      lastAppliedY: lastAppliedY ?? this.lastAppliedY,
    );
  }
}

class _ChunkRenderPlacement {
  const _ChunkRenderPlacement({
    required this.selectionKey,
    required this.placement,
    required this.prefab,
    required this.sprites,
    required this.localVisualBounds,
    required this.fallbackColor,
  });

  factory _ChunkRenderPlacement.fromPlacement({
    required String selectionKey,
    required PlacedPrefabDef placement,
    required PrefabDef? prefab,
    required Map<String, AtlasSliceDef> prefabSliceById,
    required Map<String, AtlasSliceDef> tileSliceById,
    required Map<String, TileModuleDef> moduleById,
  }) {
    final fallbackColor = _fallbackColorForId(placement.resolvedPrefabRef);
    if (prefab == null) {
      return _ChunkRenderPlacement(
        selectionKey: selectionKey,
        placement: placement,
        prefab: null,
        sprites: const <_ChunkRenderSprite>[],
        localVisualBounds: Rect.fromLTWH(-8, -8, 16, 16),
        fallbackColor: fallbackColor,
      );
    }

    if (prefab.visualSource.isAtlasSlice) {
      final slice = prefabSliceById[prefab.visualSource.sliceId];
      final width = math.max(1, slice?.width ?? 16).toDouble();
      final height = math.max(1, slice?.height ?? 16).toDouble();
      final localRect = Rect.fromLTWH(
        -prefab.anchorXPx.toDouble(),
        -prefab.anchorYPx.toDouble(),
        width,
        height,
      );
      return _ChunkRenderPlacement(
        selectionKey: selectionKey,
        placement: placement,
        prefab: prefab,
        sprites: <_ChunkRenderSprite>[
          _ChunkRenderSprite(localRect: localRect, slice: slice),
        ],
        localVisualBounds: localRect,
        fallbackColor: fallbackColor,
      );
    }

    if (prefab.visualSource.isPlatformModule) {
      final module = moduleById[prefab.visualSource.moduleId];
      if (module == null || module.cells.isEmpty) {
        return _ChunkRenderPlacement(
          selectionKey: selectionKey,
          placement: placement,
          prefab: prefab,
          sprites: const <_ChunkRenderSprite>[],
          localVisualBounds: Rect.fromLTWH(-8, -8, 16, 16),
          fallbackColor: fallbackColor,
        );
      }
      final tileSize = module.tileSize <= 0 ? 16.0 : module.tileSize.toDouble();
      Rect? moduleBounds;
      final spriteSpecs = <_ChunkRenderSprite>[];
      for (final cell in module.cells) {
        final slice = tileSliceById[cell.sliceId];
        final width = math.max(1, slice?.width ?? tileSize.toInt()).toDouble();
        final height = math
            .max(1, slice?.height ?? tileSize.toInt())
            .toDouble();
        final localCellRect = Rect.fromLTWH(
          cell.gridX * tileSize,
          cell.gridY * tileSize,
          width,
          height,
        );
        moduleBounds = moduleBounds == null
            ? localCellRect
            : moduleBounds.expandToInclude(localCellRect);
        spriteSpecs.add(
          _ChunkRenderSprite(localRect: localCellRect, slice: slice),
        );
      }
      final safeBounds =
          moduleBounds ?? Rect.fromLTWH(0, 0, tileSize, tileSize);
      final visualBounds = Rect.fromLTWH(
        -prefab.anchorXPx.toDouble(),
        -prefab.anchorYPx.toDouble(),
        safeBounds.width,
        safeBounds.height,
      );
      final normalizedSprites = spriteSpecs
          .map((sprite) {
            return _ChunkRenderSprite(
              localRect: Rect.fromLTWH(
                visualBounds.left + (sprite.localRect.left - safeBounds.left),
                visualBounds.top + (sprite.localRect.top - safeBounds.top),
                sprite.localRect.width,
                sprite.localRect.height,
              ),
              slice: sprite.slice,
            );
          })
          .toList(growable: false);
      return _ChunkRenderPlacement(
        selectionKey: selectionKey,
        placement: placement,
        prefab: prefab,
        sprites: normalizedSprites,
        localVisualBounds: visualBounds,
        fallbackColor: fallbackColor,
      );
    }

    return _ChunkRenderPlacement(
      selectionKey: selectionKey,
      placement: placement,
      prefab: prefab,
      sprites: const <_ChunkRenderSprite>[],
      localVisualBounds: Rect.fromLTWH(-8, -8, 16, 16),
      fallbackColor: fallbackColor,
    );
  }

  final String selectionKey;
  final PlacedPrefabDef placement;
  final PrefabDef? prefab;
  final List<_ChunkRenderSprite> sprites;
  final Rect localVisualBounds;
  final Color fallbackColor;

  int get zIndex => placement.zIndex;

  Rect visualWorldRect() {
    return localVisualBounds.shift(
      Offset(placement.x.toDouble(), placement.y.toDouble()),
    );
  }

  PrefabSceneValues? overlayValues() {
    final prefab = this.prefab;
    if (prefab == null) {
      return null;
    }
    return prefabSceneValuesFromPrefab(prefab);
  }
}

class _ChunkRenderMarker {
  const _ChunkRenderMarker({required this.selectionKey, required this.marker});

  static const double _markerHitSize = 14.0;

  final String selectionKey;
  final PlacedMarkerDef marker;

  Rect visualWorldRect() {
    return Rect.fromCenter(
      center: Offset(marker.x.toDouble(), marker.y.toDouble()),
      width: _markerHitSize,
      height: _markerHitSize,
    );
  }
}

class _ChunkRenderSprite {
  const _ChunkRenderSprite({required this.localRect, required this.slice});

  final Rect localRect;
  final AtlasSliceDef? slice;
}

class _ChunkSceneGeometry {
  _ChunkSceneGeometry({
    required this.chunk,
    required this.runtimeGridSnap,
    required this.renderPlacements,
    required this.renderMarkers,
    required this.viewportSize,
    required this.zoom,
    required this.canvasMargin,
  }) {
    final authoritativeGrid = runtimeGridSnap <= 0 ? 16.0 : runtimeGridSnap;
    final worldPaddingX = math.max(64.0, authoritativeGrid * 4);
    final worldPaddingTop = math.max(120.0, authoritativeGrid * 10);
    final worldPaddingBottom = math.max(72.0, authoritativeGrid * 6);
    final safeChunkWidth = math.max(1, chunk.width).toDouble();
    final safeChunkHeight = math.max(1, chunk.height).toDouble();

    // Chunk bounds represent the actual gameplay viewport frame for one chunk.
    // The visible floor area is derived separately from groundProfile.topY and
    // ground gaps, but the authored chunk frame itself remains the full
    // player-facing viewport.
    chunkRect = Rect.fromLTWH(0, 0, safeChunkWidth, safeChunkHeight);

    Rect contentBounds = chunkRect;
    for (final placement in renderPlacements) {
      contentBounds = contentBounds.expandToInclude(
        placement.visualWorldRect(),
      );
    }
    for (final marker in renderMarkers) {
      contentBounds = contentBounds.expandToInclude(marker.visualWorldRect());
    }

    worldRect = Rect.fromLTRB(
      math.min(0.0, contentBounds.left) - worldPaddingX,
      math.min(0.0, contentBounds.top) - worldPaddingTop,
      math.max(chunkRect.right, contentBounds.right) + worldPaddingX,
      math.max(chunkRect.bottom, contentBounds.bottom) + worldPaddingBottom,
    );

    final desiredWidth = (worldRect.width * zoom) + (canvasMargin * 2);
    final desiredHeight = (worldRect.height * zoom) + (canvasMargin * 2);
    canvasSize = Size(
      math.max(viewportSize.width, desiredWidth),
      math.max(viewportSize.height, desiredHeight),
    );
    worldOrigin = Offset(
      (canvasSize.width - (worldRect.width * zoom)) * 0.5,
      (canvasSize.height - (worldRect.height * zoom)) * 0.5,
    );
    worldCanvasRect = Rect.fromLTWH(
      worldOrigin.dx,
      worldOrigin.dy,
      worldRect.width * zoom,
      worldRect.height * zoom,
    );
  }

  _ChunkSceneGeometry.preview({
    required this.chunk,
    required this.runtimeGridSnap,
    required this.renderPlacements,
    required this.renderMarkers,
    required this.viewportSize,
    double padding = 6.0,
  }) : canvasMargin = 0,
       zoom = _previewZoom(
         chunk: chunk,
         viewportSize: viewportSize,
         padding: padding,
       ) {
    final safeChunkSize = _safeChunkSize(chunk);
    chunkRect = Offset.zero & safeChunkSize;
    worldRect = chunkRect;
    canvasSize = Size(
      math.max(1.0, viewportSize.width),
      math.max(1.0, viewportSize.height),
    );
    final previewCanvasRect = Alignment.center.inscribe(
      Size(chunkRect.width * zoom, chunkRect.height * zoom),
      Offset.zero & canvasSize,
    );
    worldOrigin = previewCanvasRect.topLeft;
    worldCanvasRect = previewCanvasRect;
  }

  static Size _safeChunkSize(LevelChunkDef chunk) {
    return Size(
      math.max(1, chunk.width).toDouble(),
      math.max(1, chunk.height).toDouble(),
    );
  }

  static double _previewZoom({
    required LevelChunkDef chunk,
    required Size viewportSize,
    required double padding,
  }) {
    final safeChunkSize = _safeChunkSize(chunk);
    final availableSize = Size(
      math.max(1.0, viewportSize.width - (padding * 2)),
      math.max(1.0, viewportSize.height - (padding * 2)),
    );
    final fitted = applyBoxFit(BoxFit.contain, safeChunkSize, availableSize);
    return math.min(
      fitted.destination.width / safeChunkSize.width,
      fitted.destination.height / safeChunkSize.height,
    );
  }

  final LevelChunkDef chunk;
  final double runtimeGridSnap;
  final List<_ChunkRenderPlacement> renderPlacements;
  final List<_ChunkRenderMarker> renderMarkers;
  final Size viewportSize;
  final double zoom;
  final double canvasMargin;
  late final Rect chunkRect;
  late final Rect worldRect;
  late final Size canvasSize;
  late final Offset worldOrigin;
  late final Rect worldCanvasRect;

  Offset canvasFromWorld(Offset world) {
    final localX = (world.dx - worldRect.left) * zoom;
    final localY = (world.dy - worldRect.top) * zoom;
    return Offset(worldOrigin.dx + localX, worldOrigin.dy + localY);
  }

  Rect canvasRectFromWorld(Rect world) {
    final topLeft = canvasFromWorld(world.topLeft);
    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      world.width * zoom,
      world.height * zoom,
    );
  }

  Offset? worldFromLocal(Offset localPosition) {
    if (!worldCanvasRect.contains(localPosition)) {
      return null;
    }
    final worldX =
        worldRect.left + ((localPosition.dx - worldOrigin.dx) / zoom);
    final worldY = worldRect.top + ((localPosition.dy - worldOrigin.dy) / zoom);
    return Offset(worldX, worldY);
  }

  Offset? snappedWorldPoint(Offset localPosition, double snap) {
    final world = worldFromLocal(localPosition);
    if (world == null) {
      return null;
    }
    return snapWorldPoint(world, snap);
  }

  Offset snapWorldPoint(Offset world, double snap) {
    if (snap <= 0) {
      return world;
    }
    final snappedX = (world.dx / snap).roundToDouble() * snap;
    final snappedY = (world.dy / snap).roundToDouble() * snap;
    return Offset(snappedX, snappedY);
  }

  _ChunkRenderPlacement? hitTestPlacement(
    Offset localPosition,
    List<_ChunkRenderPlacement> renderPlacements,
  ) {
    final world = worldFromLocal(localPosition);
    if (world == null) {
      return null;
    }
    for (var i = renderPlacements.length - 1; i >= 0; i -= 1) {
      final placement = renderPlacements[i];
      if (placement.visualWorldRect().contains(world)) {
        return placement;
      }
    }
    return null;
  }

  _ChunkRenderMarker? hitTestMarker(
    Offset localPosition,
    List<_ChunkRenderMarker> renderMarkers,
  ) {
    final world = worldFromLocal(localPosition);
    if (world == null) {
      return null;
    }
    for (var i = renderMarkers.length - 1; i >= 0; i -= 1) {
      final marker = renderMarkers[i];
      if (marker.visualWorldRect().contains(world)) {
        return marker;
      }
    }
    return null;
  }
}

class _ChunkScenePainter extends CustomPainter {
  const _ChunkScenePainter({
    required this.workspaceRootPath,
    required this.imageCache,
    required this.loadedImageCount,
    required this.geometry,
    required this.chunk,
    required this.showParallaxPreview,
    this.showPixelGrid = true,
    this.showChunkBounds = true,
    this.showMarkers = true,
    this.clipSceneToChunkBounds = false,
    required this.parallaxPreview,
    required this.groundLayout,
    required this.groundMaterial,
    required this.groundMaterialSrcRect,
    required this.renderPlacements,
    required this.renderMarkers,
    required this.selectedPlacement,
    required this.selectedMarker,
  });

  final String workspaceRootPath;
  final EditorUiImageCache imageCache;
  final int loadedImageCount;
  final _ChunkSceneGeometry geometry;
  final LevelChunkDef chunk;
  final bool showParallaxPreview;
  final bool showPixelGrid;
  final bool showChunkBounds;
  final bool showMarkers;
  final bool clipSceneToChunkBounds;
  final ChunkParallaxPreviewSpec parallaxPreview;
  final ChunkGroundLayout groundLayout;
  final ChunkGroundMaterialSpec groundMaterial;
  final ui.Rect? groundMaterialSrcRect;
  final List<_ChunkRenderPlacement> renderPlacements;
  final List<_ChunkRenderMarker> renderMarkers;
  final _ChunkRenderPlacement? selectedPlacement;
  final _ChunkRenderMarker? selectedMarker;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF111A22),
    );
    canvas.drawRect(
      geometry.worldCanvasRect,
      Paint()..color = const Color(0xFF0D131A),
    );
    _paintChunkBackdrop(canvas);
    if (clipSceneToChunkBounds) {
      final chunkCanvasRect = geometry.canvasRectFromWorld(geometry.chunkRect);
      canvas.save();
      canvas.clipRect(chunkCanvasRect);
      _paintSceneBody(canvas, size);
      canvas.restore();
    } else {
      _paintSceneBody(canvas, size);
    }
    if (showChunkBounds) {
      _paintChunkBounds(canvas);
    }
    _paintSelectedPlacementOverlay(canvas);
    _paintSelectedMarkerOverlay(canvas);
  }

  void _paintSceneBody(Canvas canvas, Size size) {
    if (showParallaxPreview) {
      _paintParallaxBackground(canvas);
    }
    if (showPixelGrid) {
      _paintPixelGrid(canvas, size);
    }
    _paintSceneContentLayers(canvas);
    if (showMarkers) {
      _paintMarkers(canvas);
    }
    if (showParallaxPreview) {
      _paintParallaxForeground(canvas);
    }
  }

  void _paintParallaxBackground(Canvas canvas) {
    _paintParallaxLayersOverChunk(canvas, parallaxPreview.backgroundLayers);
  }

  void _paintParallaxForeground(Canvas canvas) {
    _paintParallaxLayersOnGroundBands(canvas, parallaxPreview.foregroundLayers);
  }

  void _paintParallaxLayersOverChunk(
    Canvas canvas,
    List<ChunkParallaxLayerPreviewSpec> layerSpecs,
  ) {
    if (layerSpecs.isEmpty) {
      return;
    }
    final chunkRect = geometry.chunkRect;
    final chunkWidth = chunkRect.width;
    if (chunkWidth <= 0) {
      return;
    }
    final anchorWorldY = chunk.groundProfile.topY.toDouble();
    final chunkCanvasRect = geometry.canvasRectFromWorld(geometry.chunkRect);
    canvas.save();
    canvas.clipRect(chunkCanvasRect);
    for (final layer in layerSpecs) {
      final image = _resolveParallaxImage(layer.assetPath);
      if (image == null) {
        continue;
      }
      _paintTiledParallaxBand(
        canvas,
        image: image,
        anchorWorldY: anchorWorldY,
        minWorldX: chunkRect.left,
        maxWorldX: chunkRect.right,
        parallaxFactor: layer.parallaxFactor,
      );
    }
    canvas.restore();
  }

  void _paintParallaxLayersOnGroundBands(
    Canvas canvas,
    List<ChunkParallaxLayerPreviewSpec> layerSpecs,
  ) {
    if (layerSpecs.isEmpty || groundLayout.solidWorldRects.isEmpty) {
      return;
    }
    for (final band in groundLayout.solidWorldRects) {
      final bandCanvasRect = geometry.canvasRectFromWorld(band);
      if (bandCanvasRect.width <= 0 || bandCanvasRect.height <= 0) {
        continue;
      }
      canvas.save();
      canvas.clipRect(bandCanvasRect);
      for (final layer in layerSpecs) {
        final image = _resolveParallaxImage(layer.assetPath);
        if (image == null) {
          continue;
        }
        _paintTiledParallaxBand(
          canvas,
          image: image,
          anchorWorldY: band.bottom,
          minWorldX: band.left,
          maxWorldX: band.right,
          parallaxFactor: layer.parallaxFactor,
        );
      }
      canvas.restore();
    }
  }

  void _paintTiledParallaxBand(
    Canvas canvas, {
    required ui.Image image,
    required double anchorWorldY,
    required double minWorldX,
    required double maxWorldX,
    required double parallaxFactor,
  }) {
    final imageWorldWidth = image.width.toDouble();
    if (imageWorldWidth <= 0) {
      return;
    }
    final cameraLeftWorldX = geometry.chunkRect.left;
    final scroll = _positiveModDouble(
      cameraLeftWorldX * parallaxFactor,
      imageWorldWidth,
    );
    final startOffsetWorldX = _positiveModDouble(-scroll, imageWorldWidth);
    final startTile =
        ((minWorldX - (geometry.chunkRect.left + startOffsetWorldX)) /
                imageWorldWidth)
            .floor() -
        1;
    final endTile =
        ((maxWorldX - (geometry.chunkRect.left + startOffsetWorldX)) /
                imageWorldWidth)
            .ceil() +
        1;

    final topWorldY = anchorWorldY - image.height.toDouble();
    for (var tile = startTile; tile <= endTile; tile += 1) {
      final tileWorldX =
          geometry.chunkRect.left + startOffsetWorldX + tile * imageWorldWidth;
      final dstRect = geometry.canvasRectFromWorld(
        Rect.fromLTWH(
          tileWorldX,
          topWorldY,
          imageWorldWidth,
          image.height.toDouble(),
        ),
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        dstRect,
        Paint()..filterQuality = FilterQuality.none,
      );
    }
  }

  void _paintChunkBackdrop(Canvas canvas) {
    final canvasRect = geometry.canvasRectFromWorld(geometry.chunkRect);
    canvas.drawRect(canvasRect, Paint()..color = const Color(0x141D2B38));
  }

  void _paintPixelGrid(Canvas canvas, Size size) {
    final snapSpacing = geometry.runtimeGridSnap <= 0
        ? 16.0
        : geometry.runtimeGridSnap;

    void paintLayer(double spacing, Color color) {
      EditorViewportGridPainter.world(
        zoom: geometry.zoom,
        worldRect: geometry.worldRect,
        worldOrigin: geometry.worldOrigin,
        worldSpacingPx: spacing,
        worldGridColor: color,
        showWorldAxes: false,
      ).paint(canvas, size);
    }

    paintLayer(1.0, EditorViewportGridPainter.minorGridColor);
    paintLayer(snapSpacing, EditorViewportGridPainter.gridColor);
    paintLayer(snapSpacing * 2, EditorViewportGridPainter.majorGridColor);
  }

  void _paintChunkGround(Canvas canvas) {
    if (!groundLayout.hasVisibleGround) {
      return;
    }
    for (final worldRect in groundLayout.solidWorldRects) {
      _paintGroundSegment(canvas, worldRect);
    }
    for (final worldRect in groundLayout.gapWorldRects) {
      _paintGap(canvas, worldRect);
    }
  }

  void _paintSceneContentLayers(Canvas canvas) {
    // Ground is chunk-authored scene content now, so it participates in the
    // same z ordering as placed prefabs. Editor chrome (frame/selection) is
    // painted after this pass so chunk bounds remain readable.
    final layers = <_ChunkSceneContentLayer>[
      _ChunkSceneContentLayer.ground(zIndex: chunk.groundBandZIndex),
      ...renderPlacements.map(_ChunkSceneContentLayer.prefab),
    ]..sort(_compareChunkSceneContentLayers);

    for (final layer in layers) {
      if (layer.prefab != null) {
        _paintPlacement(canvas, layer.prefab!);
        continue;
      }
      _paintChunkGround(canvas);
    }
  }

  void _paintGroundSegment(Canvas canvas, Rect worldRect) {
    final groundImage = _resolveGroundMaterialImage();
    final groundMaterialSrcRect = this.groundMaterialSrcRect;
    if (groundImage == null || groundMaterialSrcRect == null) {
      _paintGroundSegmentFallback(canvas, worldRect);
      return;
    }
    final canvasRect = geometry.canvasRectFromWorld(worldRect);
    canvas.save();
    canvas.clipRect(canvasRect);
    final tileWidth = groundImage.width.toDouble();
    final startTile = (worldRect.left / tileWidth).floor() - 1;
    final endTile = (worldRect.right / tileWidth).ceil() + 1;
    for (var tile = startTile; tile <= endTile; tile += 1) {
      final tileWorldX = tile * tileWidth;
      final dstRect = geometry.canvasRectFromWorld(
        Rect.fromLTWH(tileWorldX, worldRect.top, tileWidth, worldRect.height),
      );
      canvas.drawImageRect(
        groundImage,
        groundMaterialSrcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.none,
      );
    }
    canvas.restore();
  }

  void _paintGroundSegmentFallback(Canvas canvas, Rect worldRect) {
    final canvasRect = geometry.canvasRectFromWorld(worldRect);
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        canvasRect.topCenter,
        canvasRect.bottomCenter,
        const [Color(0x665A7442), Color(0x33312221)],
      );
    canvas.drawRect(canvasRect, fillPaint);
    final topLine = Paint()
      ..color = const Color(0xD9F4E4A5)
      ..strokeWidth = 1.4;
    canvas.drawLine(canvasRect.topLeft, canvasRect.topRight, topLine);
  }

  void _paintGap(Canvas canvas, Rect worldRect) {
    final canvasRect = geometry.canvasRectFromWorld(worldRect);
    canvas.drawRect(
      canvasRect,
      Paint()
        ..shader = ui.Gradient.linear(
          canvasRect.topCenter,
          canvasRect.bottomCenter,
          const [Color(0x22000000), Color(0xA3081118)],
        ),
    );
    final edgeWidth = math.min(
      canvasRect.width * 0.18,
      math.max(6.0, 8.0 * geometry.zoom),
    );
    if (edgeWidth > 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          canvasRect.left,
          canvasRect.top,
          edgeWidth,
          canvasRect.height,
        ),
        Paint()
          ..shader = ui.Gradient.linear(
            canvasRect.topLeft,
            Offset(canvasRect.left + edgeWidth, canvasRect.top),
            const [Color(0x8A140E0A), Color(0x00140E0A)],
          ),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          canvasRect.right - edgeWidth,
          canvasRect.top,
          edgeWidth,
          canvasRect.height,
        ),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(canvasRect.right - edgeWidth, canvasRect.top),
            canvasRect.topRight,
            const [Color(0x00140E0A), Color(0x8A140E0A)],
          ),
      );
    }
    canvas.drawLine(
      canvasRect.topLeft,
      canvasRect.topRight,
      Paint()
        ..color = const Color(0xAA10171D)
        ..strokeWidth = 1.3,
    );
  }

  void _paintChunkBounds(Canvas canvas) {
    final canvasRect = geometry.canvasRectFromWorld(geometry.chunkRect);
    final borderPaint = Paint()
      ..color = const Color(0xFF7CB7E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawRect(canvasRect, borderPaint);
    final accentPaint = Paint()
      ..color = const Color(0xFFE6F1FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final cornerLength = math.min(18.0, math.max(10.0, 12.0 * geometry.zoom));

    void drawCorner({
      required Offset corner,
      required Offset horizontalDirection,
      required Offset verticalDirection,
    }) {
      canvas.drawLine(corner, corner + horizontalDirection, accentPaint);
      canvas.drawLine(corner, corner + verticalDirection, accentPaint);
    }

    drawCorner(
      corner: canvasRect.topLeft,
      horizontalDirection: Offset(cornerLength, 0),
      verticalDirection: Offset(0, cornerLength),
    );
    drawCorner(
      corner: canvasRect.topRight,
      horizontalDirection: Offset(-cornerLength, 0),
      verticalDirection: Offset(0, cornerLength),
    );
    drawCorner(
      corner: canvasRect.bottomLeft,
      horizontalDirection: Offset(cornerLength, 0),
      verticalDirection: Offset(0, -cornerLength),
    );
    drawCorner(
      corner: canvasRect.bottomRight,
      horizontalDirection: Offset(-cornerLength, 0),
      verticalDirection: Offset(0, -cornerLength),
    );
  }

  void _paintPlacement(Canvas canvas, _ChunkRenderPlacement placement) {
    if (placement.sprites.isEmpty) {
      final fallbackRect = geometry.canvasRectFromWorld(
        placement.visualWorldRect(),
      );
      canvas.drawRect(
        fallbackRect,
        Paint()
          ..color = placement.fallbackColor.withAlpha(115)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        fallbackRect,
        Paint()
          ..color = placement.fallbackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      return;
    }

    for (final sprite in placement.sprites) {
      final worldRect = sprite.localRect.shift(
        Offset(
          placement.placement.x.toDouble(),
          placement.placement.y.toDouble(),
        ),
      );
      final canvasRect = geometry.canvasRectFromWorld(worldRect);
      final slice = sprite.slice;
      final image = slice == null ? null : _resolveSliceImage(slice);
      if (slice != null && image != null) {
        final srcRect = Rect.fromLTWH(
          slice.x.toDouble(),
          slice.y.toDouble(),
          slice.width.toDouble(),
          slice.height.toDouble(),
        );
        canvas.drawImageRect(
          image,
          srcRect,
          canvasRect,
          Paint()..filterQuality = FilterQuality.none,
        );
      } else {
        canvas.drawRect(
          canvasRect,
          Paint()
            ..color = placement.fallbackColor
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  void _paintSelectedPlacementOverlay(Canvas canvas) {
    final selectedPlacement = this.selectedPlacement;
    if (selectedPlacement == null) {
      return;
    }
    final highlightRect = geometry.canvasRectFromWorld(
      selectedPlacement.visualWorldRect(),
    );
    canvas.drawRect(
      highlightRect.inflate(2.0),
      Paint()
        ..color = const Color(0xFFFFD166)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    final overlayValues = selectedPlacement.overlayValues();
    if (overlayValues == null) {
      return;
    }
    final overlayGeometry = PrefabOverlayHandleGeometry.fromValues(
      values: overlayValues,
      anchorCanvasBase: geometry.canvasFromWorld(
        selectedPlacement.visualWorldRect().topLeft,
      ),
      zoom: geometry.zoom,
    );
    PrefabOverlayPainter.paint(
      canvas: canvas,
      geometry: overlayGeometry,
      drawHandles: false,
    );
  }

  void _paintMarkers(Canvas canvas) {
    for (final marker in renderMarkers) {
      final center = geometry.canvasFromWorld(
        Offset(marker.marker.x.toDouble(), marker.marker.y.toDouble()),
      );
      final radius = math.max(5.0, 4.0 * geometry.zoom);
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = const Color(0xFFEA5A5A).withValues(alpha: 0.42),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFFFFADAD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      canvas.drawLine(
        Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy),
        Paint()
          ..color = const Color(0xFFFFD3D3)
          ..strokeWidth = 1.1,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius),
        Paint()
          ..color = const Color(0xFFFFD3D3)
          ..strokeWidth = 1.1,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: marker.marker.markerId,
          style: TextStyle(
            color: const Color(0xFFFFE8E8),
            fontSize: math.max(9.0, 7.5 * geometry.zoom),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(center.dx + radius + 4.0, center.dy - textPainter.height * 0.5),
      );
    }
  }

  void _paintSelectedMarkerOverlay(Canvas canvas) {
    final marker = selectedMarker;
    if (marker == null) {
      return;
    }
    final center = geometry.canvasFromWorld(
      Offset(marker.marker.x.toDouble(), marker.marker.y.toDouble()),
    );
    final radius = math.max(7.0, 5.5 * geometry.zoom);
    canvas.drawCircle(
      center,
      radius + 2,
      Paint()
        ..color = const Color(0xFFFFD166)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  ui.Image? _resolveSliceImage(AtlasSliceDef slice) {
    final absolutePath = p.normalize(
      p.join(workspaceRootPath, slice.sourceImagePath),
    );
    return imageCache.imageFor(absolutePath);
  }

  ui.Image? _resolveGroundMaterialImage() {
    final absolutePath = p.normalize(
      p.join(workspaceRootPath, groundMaterial.sourceImagePath),
    );
    return imageCache.imageFor(absolutePath);
  }

  ui.Image? _resolveParallaxImage(String sourceImagePath) {
    final absolutePath = p.normalize(
      p.join(workspaceRootPath, sourceImagePath),
    );
    return imageCache.imageFor(absolutePath);
  }

  @override
  bool shouldRepaint(covariant _ChunkScenePainter oldDelegate) {
    return oldDelegate.geometry.zoom != geometry.zoom ||
        oldDelegate.chunk != chunk ||
        oldDelegate.showParallaxPreview != showParallaxPreview ||
        oldDelegate.showPixelGrid != showPixelGrid ||
        oldDelegate.showChunkBounds != showChunkBounds ||
        oldDelegate.showMarkers != showMarkers ||
        oldDelegate.clipSceneToChunkBounds != clipSceneToChunkBounds ||
        oldDelegate.groundMaterial.sourceImagePath !=
            groundMaterial.sourceImagePath ||
        oldDelegate.groundMaterialSrcRect != groundMaterialSrcRect ||
        oldDelegate.selectedPlacement != selectedPlacement ||
        oldDelegate.selectedMarker != selectedMarker ||
        oldDelegate.renderPlacements != renderPlacements ||
        oldDelegate.renderMarkers != renderMarkers ||
        oldDelegate.loadedImageCount != loadedImageCount;
  }
}

double _positiveModDouble(double value, double modulus) {
  if (modulus == 0) {
    return 0;
  }
  final result = value % modulus;
  return result < 0 ? result + modulus : result;
}

int _compareRenderPlacements(_ChunkRenderPlacement a, _ChunkRenderPlacement b) {
  final zCompare = a.zIndex.compareTo(b.zIndex);
  if (zCompare != 0) {
    return zCompare;
  }
  return comparePlacedPrefabsDeterministic(a.placement, b.placement);
}

int _compareRenderMarkers(_ChunkRenderMarker a, _ChunkRenderMarker b) {
  return comparePlacedMarkersDeterministic(a.marker, b.marker);
}

class _ChunkSceneContentLayer {
  _ChunkSceneContentLayer._({
    required this.zIndex,
    required this.isGround,
    this.prefab,
  });

  _ChunkSceneContentLayer.ground({required int zIndex})
    : this._(zIndex: zIndex, isGround: true);

  _ChunkSceneContentLayer.prefab(_ChunkRenderPlacement placement)
    : this._(zIndex: placement.zIndex, isGround: false, prefab: placement);

  final int zIndex;
  final bool isGround;
  final _ChunkRenderPlacement? prefab;
}

int _compareChunkSceneContentLayers(
  _ChunkSceneContentLayer a,
  _ChunkSceneContentLayer b,
) {
  final zCompare = a.zIndex.compareTo(b.zIndex);
  if (zCompare != 0) {
    return zCompare;
  }
  if (a.isGround != b.isGround) {
    return a.isGround ? -1 : 1;
  }
  final leftPrefab = a.prefab;
  final rightPrefab = b.prefab;
  if (leftPrefab == null || rightPrefab == null) {
    return 0;
  }
  return comparePlacedPrefabsDeterministic(
    leftPrefab.placement,
    rightPrefab.placement,
  );
}

Color _fallbackColorForId(String raw) {
  var hash = 0;
  for (final code in raw.codeUnits) {
    hash = ((hash * 31) + code) & 0x7fffffff;
  }
  final hue = (hash % 360).toDouble();
  return HSVColor.fromAHSV(1.0, hue, 0.42, 0.88).toColor();
}
