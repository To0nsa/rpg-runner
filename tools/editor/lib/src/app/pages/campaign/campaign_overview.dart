import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/interactions/world_interaction_catalog.dart';
import 'package:runner_core/interactions/world_interaction_render_catalog.dart';
import 'package:runner_core/pickups/pickup_render_catalog.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/traps/trap_geometry.dart';

import '../../../campaign/campaign_marker_edit.dart';
import '../../../chunks/chunk_encounter_edit.dart';
import '../../../chunks/chunk_marker_authoring_catalog.dart';
import '../../../chunks/chunk_scene_coordinate_policy.dart';
import '../../../chunks/chunk_v2_models.dart';
import '../../../chunks/chunk_v2_actor_terrain_projection.dart';
import '../../../parallax/parallax_domain_models.dart';
import '../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../chunkCreator/v2/chunk_actor_idle_frame.dart';
import '../chunkCreator/v2/chunk_composition_preview.dart';
import '../shared/editor_scene_view_utils.dart';
import '../shared/scene_input_utils.dart';
import '../shared/scene_rectangle_gesture.dart';
import 'campaign_marker_editing.dart';
import 'campaign_marker_painter.dart';
import 'campaign_actor_preview.dart';
import 'campaign_scene_controls.dart';

/// One assembled preview shared by Route and Markers. Editing adds input and
/// overlays to the same chunk art, viewport and occurrence coordinate mapping.
class CampaignOverview extends StatefulWidget {
  const CampaignOverview({
    super.key,
    required this.mission,
    required this.chunks,
    required this.workspaceRootPath,
    this.editing,
    this.showControls = false,
    this.visualPreview = false,
    this.onVisualPreviewChanged,
  });
  final CampaignMissionSource mission;
  final ChunkV2Document chunks;
  final String workspaceRootPath;
  final CampaignMarkerEditing? editing;
  final bool showControls, visualPreview;
  final ValueChanged<bool>? onVisualPreviewChanged;
  @override
  State<CampaignOverview> createState() => _CampaignOverviewState();
}

class _CampaignOverviewState extends State<CampaignOverview> {
  final _horizontal = ScrollController(), _vertical = ScrollController();
  final _images = EditorUiImageCache();
  double _zoom = 1;
  bool _showGrid = false, _showActorTerrain = false;
  ChunkV2TerrainActor _actor = ChunkV2TerrainActor.eloise;
  int? _pointer;
  bool _panning = false;
  CampaignMarkerEntry? _before;
  CampaignMissionSource? _expected;
  Offset _grab = Offset.zero;
  SceneRectangleGesture? _rectangle;

  @override
  void initState() {
    super.initState();
    unawaited(_loadArt());
  }

  @override
  void didUpdateWidget(covariant CampaignOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editing != oldWidget.editing ||
        widget.mission.id != oldWidget.mission.id) {
      _cancel();
    }
  }

  Future<void> _loadArt() async {
    final root = widget.workspaceRootPath;
    final frames = [
      for (final variant in [
        PickupVariant.collectible,
        PickupVariant.restorationHealth,
        PickupVariant.restorationMana,
        PickupVariant.restorationStamina,
      ])
        ChunkActorIdleFrame.fromDefinition(
          renderAnim: const PickupRenderCatalog().get(variant),
          renderScale: 1,
          workspaceRootPath: root,
        ),
      for (final enemy in chunkMarkerEnemyCatalog)
        ChunkActorIdleFrame.fromEnemy(enemy: enemy, workspaceRootPath: root),
    ];
    await Future.wait([
      for (final path in {
        for (final f in frames)
          if (f != null) f.absoluteSourcePath,
        for (final id in WorldInteractionAppearanceId.values)
          '$root/assets/images/${WorldInteractionRenderCatalog.get(id).assetPaths.first}',
      })
        _images.ensureLoaded(path),
    ]);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    _images.dispose();
    super.dispose();
  }

  CampaignPoint _point(int index, Offset local, double scale) {
    final worldX = index * 600 + local.dx / scale;
    final occurrence = (worldX / 600).floor();
    if (occurrence < 0 || occurrence >= widget.mission.route.length) {
      throw StateError('Place inside the mission route.');
    }
    final step = widget.editing?.snap == true ? 8 : 1;
    return CampaignPoint(
      occurrenceId: widget.mission.route[occurrence].id,
      x: quantizeChunkSceneCoordinate(
        worldX - occurrence * 600,
        step: step,
      ).clamp(0, 599).toDouble(),
      y: quantizeChunkSceneCoordinate(
        local.dy / scale,
        step: step,
      ).clamp(0, 270).toDouble(),
    );
  }

  void _cancel() {
    _pointer = null;
    _rectangle = null;
    _before = null;
    _expected = null;
    _panning = false;
    widget.editing?.candidate = null;
    widget.editing?.gestureActive = false;
  }

  CampaignMarkerEntry? _hit(CampaignPoint point, double scale) {
    final pos = Offset(point.x, point.y);
    for (final entry
        in (widget.editing?.entries ?? campaignMarkerEntries(widget.mission))
            .reversed) {
      if (entry.position.occurrenceId != point.occurrenceId) continue;
      final region = campaignMarkerRegion(entry);
      if ((region?.inflate(7 / scale).contains(pos) ?? false) ||
          (pos - Offset(entry.position.x, entry.position.y)).distance <=
              14 / scale) {
        return entry;
      }
    }
    return null;
  }

  void _down(PointerDownEvent event, int index, double scale) {
    if (_pointer != null ||
        !SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
      return;
    }
    final edit = widget.editing;
    _panning = SceneInputUtils.shouldPanWithPrimaryDrag(event.buttons);
    if (_panning) {
      _pointer = event.pointer;
      return;
    }
    if (edit == null || widget.visualPreview || !edit.finishDraft()) return;
    _pointer = event.pointer;
    _expected = edit.mission;
    try {
      final point = _point(index, event.localPosition, scale);
      _before = edit.tool == CampaignMarkerTool.place
          ? null
          : _hit(point, scale);
      if (edit.tool != CampaignMarkerTool.place && _before == null) {
        edit.select(null);
        _cancel();
        return;
      }
      if (_before != null) {
        edit.select(_before!.key);
        _grab = Offset(
          point.x - _before!.position.x,
          point.y - _before!.position.y,
        );
        final bounds = campaignMarkerRegion(_before!);
        final corner = bounds == null
            ? null
            : hitTestSceneRectangleCorner(
                bounds: bounds,
                worldPoint: Offset(point.x, point.y),
                zoom: scale,
              );
        if (corner != null) {
          _rectangle = SceneRectangleGesture(
            pointer: event.pointer,
            worldPoint: Offset(point.x, point.y),
            limit: const Size(600, 270),
            snapPolicy: edit.snap
                ? TerrainPolygonSnapPolicy.ownerGridPixels(8)
                : const TerrainPolygonSnapPolicy.halfPixel(),
            neighbors: const [],
            snapToNeighbors: false,
            zoom: scale,
            original: bounds,
            corner: corner,
          );
        }
      } else {
        _grab = Offset.zero;
      }
      edit.gestureActive = true;
      _preview(event.localPosition, index, scale);
    } on Object catch (e) {
      edit.error = '$e';
      _cancel();
      edit.changed();
    }
  }

  void _preview(Offset local, int index, double scale) {
    final edit = widget.editing!;
    try {
      final point = _point(index, local, scale);
      final before = _before;
      CampaignMarkerEntry candidate;
      if (before == null) {
        candidate = edit.create(point);
      } else if (_rectangle != null) {
        if (point.occurrenceId != before.position.occurrenceId) {
          throw StateError('Resize inside the selected occurrence.');
        }
        _rectangle!.update(
          pointer: _pointer!,
          worldPoint: Offset(point.x, point.y),
          zoom: scale,
        );
        final bounds = _rectangle!.bounds;
        final origin = CampaignPoint(
          occurrenceId: point.occurrenceId,
          x: bounds.left,
          y: bounds.top,
        );
        final p = before.placement;
        final CampaignPlacementSource? placement = switch (p) {
          CampaignTrapSource p => CampaignTrapSource(
            p.id,
            p.occurrenceId,
            p.trap.copyWith(
              trigger: TrapRect(
                (bounds.left - p.trap.x).round(),
                (bounds.top - p.trap.y).round(),
                bounds.width.round(),
                bounds.height.round(),
              ),
            ),
          ),
          CampaignRescueSource p => CampaignRescueSource(
            p.id,
            p.occurrenceId,
            editEncounter(
              p.encounter,
              trigger: EncounterTrigger(
                x: bounds.left,
                y: bounds.top,
                width: bounds.width,
                height: bounds.height,
              ),
            ),
            required: p.required,
          ),
          _ => null,
        };
        candidate = CampaignMarkerEntry(
          before.key,
          placement?.position ?? origin,
          placement: placement,
          region: placement == null
              ? CampaignRegion(
                  origin: origin,
                  width: bounds.width,
                  height: bounds.height,
                )
              : null,
        );
      } else {
        candidate = edit.move(
          before,
          CampaignPoint(
            occurrenceId: point.occurrenceId,
            x: point.x - _grab.dx,
            y: point.y - _grab.dy,
          ),
        );
      }
      edit.candidate = candidate;
      edit.error = null;
    } on Object catch (e) {
      edit.candidate = null;
      edit.error = '$e';
    }
    edit.changed();
  }

  void _move(PointerMoveEvent event, int index, double scale) {
    if (_pointer != event.pointer) return;
    if (_panning) {
      SceneInputUtils.panScrollControllers(
        horizontal: _horizontal,
        vertical: _vertical,
        pointerDelta: event.delta,
      );
    } else if (widget.editing?.gestureActive == true) {
      _preview(event.localPosition, index, scale);
    }
  }

  void _up(PointerUpEvent event, int index, double scale) {
    if (_pointer != event.pointer) return;
    final edit = widget.editing;
    if (edit != null && !_panning && edit.gestureActive) {
      _preview(event.localPosition, index, scale);
      final candidate = edit.candidate;
      final before = _before, expected = _expected;
      _cancel();
      if (candidate != null) {
        edit.error = edit.commit(before, candidate, expected: expected);
      }
    }
    _cancel();
    edit?.changed();
  }

  void _hover(PointerHoverEvent event, int index, double scale) {
    final edit = widget.editing;
    if (edit == null ||
        widget.visualPreview ||
        _pointer != null ||
        edit.tool != CampaignMarkerTool.place) {
      return;
    }
    _before = null;
    _preview(event.localPosition, index, scale);
  }

  void _signal(PointerSignalEvent event) {
    if (widget.editing?.gestureActive == true) return;
    final steps = SceneInputUtils.signedZoomStepsFromCtrlScroll(event);
    if (steps == 0) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      _setZoom(_zoom + steps * .25);
    });
  }

  void _setZoom(double value) => setState(() {
    _zoom = EditorSceneViewUtils.snapZoom(
      value: value,
      min: .5,
      max: 4,
      step: .25,
    );
    widget.editing?.candidate = null;
  });

  void _resetView() {
    _setZoom(1);
    if (_horizontal.hasClients) _horizontal.jumpTo(0);
    if (_vertical.hasClients) _vertical.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.showControls && widget.editing != null)
        CampaignSceneControls(
          editing: widget.editing!,
          visualPreview: widget.visualPreview,
          onVisualPreviewChanged: widget.onVisualPreviewChanged!,
          showGrid: _showGrid,
          onGridChanged: (value) => setState(() => _showGrid = value),
          showActorTerrain: _showActorTerrain,
          onActorTerrainChanged: (value) =>
              setState(() => _showActorTerrain = value),
          actor: _actor,
          onActorChanged: (value) => setState(() => _actor = value),
          zoom: _zoom,
          onZoomChanged: _setZoom,
          onResetView: _resetView,
        ),
      Expanded(
        key: const ValueKey('campaign_route_canvas'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.mission.route.isEmpty
                ? const Center(
                    child: Text(
                      'Add chunks from Contents to build this mission.',
                    ),
                  )
                : _canvas(context),
            // Feedback must not resize the canvas: its height defines both
            // route scale and pointer coordinates during placement.
            if (widget.showControls && !widget.visualPreview)
              if (widget.editing?.error case final error?)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: IgnorePointer(
                    child: Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    ],
  );

  Widget _canvas(BuildContext context) {
    final mission = widget.mission, edit = widget.editing;
    final chunks = {for (final c in widget.chunks.chunks) c.chunkKey: c};
    final theme = findParallaxThemeById(
      widget.chunks.parallaxThemes,
      mission.visualThemeId,
    );
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        dragDevices: edit == null ? null : const <PointerDeviceKind>{},
      ),
      child: Scrollbar(
        controller: _horizontal,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        thumbVisibility: true,
        interactive: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxHeight <= 0 || constraints.maxWidth <= 0) {
                return const SizedBox.shrink();
              }
              final height = constraints.maxHeight * _zoom,
                  scale = height / 270;
              return SingleChildScrollView(
                controller: _vertical,
                padding: EdgeInsets.symmetric(
                  vertical: _zoom < 1
                      ? (constraints.maxHeight - height) / 2
                      : 0,
                ),
                child: SizedBox(
                  height: height,
                  width: constraints.maxWidth,
                  child: ListView.builder(
                    key: PageStorageKey('campaign_route_preview_${mission.id}'),
                    controller: _horizontal,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    itemExtent: 600 * scale,
                    itemCount: mission.route.length,
                    itemBuilder: (context, index) {
                      final occurrence = mission.route[index],
                          chunk = chunks[occurrence.chunkKey];
                      final entries = [
                        for (final e in campaignMarkerEntries(mission))
                          if (e.position.occurrenceId == occurrence.id &&
                              e.key != edit?.candidate?.key)
                            e,
                        if (edit?.candidate?.position.occurrenceId ==
                            occurrence.id)
                          edit!.candidate!,
                      ];
                      return Listener(
                        onPointerDown: (e) => _down(e, index, scale),
                        onPointerMove: (e) => _move(e, index, scale),
                        onPointerUp: (e) => _up(e, index, scale),
                        onPointerHover: (e) => _hover(e, index, scale),
                        onPointerCancel: (_) {
                          _cancel();
                          edit?.changed();
                        },
                        onPointerSignal: _signal,
                        behavior: HitTestBehavior.opaque,
                        child: CustomPaint(
                          key: ValueKey('campaign_preview_${occurrence.id}'),
                          foregroundPainter: widget.visualPreview
                              ? null
                              : CampaignMarkerPainter(
                                  entries: campaignMarkerEntries(mission),
                                  occurrenceId: occurrence.id,
                                  scale: scale,
                                  root: widget.workspaceRootPath,
                                  images: _images,
                                  selectedKey: edit?.selectedKey,
                                  candidate: edit?.candidate,
                                  showGrid: _showGrid,
                                ),
                          child: chunk == null
                              ? Center(
                                  child: Text(
                                    'Missing chunk: ${occurrence.chunkKey}',
                                  ),
                                )
                              : Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ChunkCompositionPreview.joined(
                                      workspaceRootPath:
                                          widget.workspaceRootPath,
                                      chunk: chunk,
                                      prefabData: widget.chunks.prefabData,
                                      tileData: widget.chunks.tileData,
                                      visualBoundsByPrefabKey:
                                          widget.chunks.visualBoundsByPrefabKey,
                                      parallaxTheme: theme,
                                    ),
                                    Offstage(
                                      offstage: widget.visualPreview,
                                      child: CampaignActorPreview(
                                        chunk: chunk,
                                        prefabs: widget.chunks.prefabData,
                                        entries: entries,
                                        root: widget.workspaceRootPath,
                                        scale: scale,
                                        images: _images,
                                        selectedKey: edit?.selectedKey,
                                        frame: edit?.trapFrame ?? 0,
                                        terrainActor:
                                            _showActorTerrain &&
                                                !widget.visualPreview
                                            ? _actor
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
