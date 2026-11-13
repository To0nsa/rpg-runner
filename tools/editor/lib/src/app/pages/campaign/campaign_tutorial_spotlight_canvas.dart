import 'dart:math' as math;

import 'package:rpg_runner/ui/hud/game/level_blessings_hud.dart';
import 'package:runner_core/interactions/level_blessing.dart';

import 'package:rpg_runner/ui/controls/widgets/jump_control.dart';
import 'package:rpg_runner/ui/controls/widgets/tap_ability_control.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:rpg_runner/ui/hud/game/resource_bars_panel.dart';
import 'package:rpg_runner/ui/campaign/campaign_hud.dart';
import 'package:runner_core/snapshots/campaign_snapshot.dart';
import 'package:rpg_runner/ui/hud/game/score_overlay.dart';
import 'package:rpg_runner/ui/hud/game/run_hud_actions_row.dart';
import 'package:rpg_runner/ui/components/hud_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:rpg_runner/playtest.dart';
import 'package:rpg_runner/ui/controls/controls_tuning.dart';
import 'package:rpg_runner/ui/controls/widgets/movement_control.dart';
import 'package:rpg_runner/ui/controls/widgets/movement_control_placement.dart';
import 'package:rpg_runner/ui/tutorial/campaign_tutorial_overlay.dart';
import 'package:rpg_runner/ui/tutorial/campaign_tutorial_geometry.dart';
import 'package:runner_content_pipeline/campaign_tutorial.dart';

import '../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../shared/scene_rectangle_gesture.dart';
import '../shared/scene_input_utils.dart';

/// Edits relative spotlight geometry over the same control and placement widgets
/// as gameplay. This fitted layout diagram does not alter calibrated Play scale.
class CampaignTutorialSpotlightCanvas extends StatefulWidget {
  const CampaignTutorialSpotlightCanvas({
    super.key,
    required this.mode,
    this.target = CampaignTutorialTarget.movement,
    required this.spotlight,
    required this.onChanged,
    this.worldTarget,
    this.worldPreview,
  });
  final Rect? worldTarget;
  final Widget? worldPreview;
  final MovementControlMode mode;
  final CampaignTutorialTarget target;
  final TutorialSpotlight spotlight;
  final ValueChanged<TutorialSpotlight> onChanged;

  @override
  State<CampaignTutorialSpotlightCanvas> createState() => _CanvasState();
}

class _CanvasState extends State<CampaignTutorialSpotlightCanvas> {
  final _targetKey = GlobalKey();
  final _surfaceKey = GlobalKey();
  String _device = 'iPhone 12 Pro';
  bool _draw = false;
  SceneRectangleGesture? _gesture;
  Rect? _draft;
  Rect? _gestureTarget;
  int? _pointer;

  // The authored envelope spans offsets [-2, 2] plus size up to 4. Give the
  // shared nonnegative rectangle helper this translated space so oversized or
  // edge-crossing openings can move without being clamped to the device frame.
  Offset get _gestureOrigin =>
      _gestureTarget!.topLeft -
      Offset(_gestureTarget!.width * 2, _gestureTarget!.height * 2);

  Size get _size {
    final device = RunnerPlaytestDevicePresets.devices[_device]!;
    return Size(device.width.toDouble(), device.height.toDouble());
  }

  Rect? _target() {
    if (widget.target.isWorld) {
      final bounds = widget.worldTarget;
      if (bounds == null) return null;
      final scale = math.min(_size.width / 600, _size.height / 270);
      return Rect.fromLTWH(
        (_size.width - 600 * scale) / 2 + bounds.left * scale,
        (_size.height - 270 * scale) / 2 + bounds.top * scale,
        bounds.width * scale,
        bounds.height * scale,
      );
    }
    final target = _targetKey.currentContext?.findRenderObject();
    final surface = _surfaceKey.currentContext?.findRenderObject();
    if (target is! RenderBox || surface is! RenderBox || !target.hasSize) {
      return null;
    }
    return surface.globalToLocal(target.localToGlobal(Offset.zero)) &
        target.size;
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null ||
        !SceneInputUtils.isPrimaryButtonPressed(event.buttons) ||
        SceneInputUtils.isCtrlPressed()) {
      return;
    }
    final target = _target();
    if (target == null) return;
    final bounds = tutorialSpotlightRect(target, widget.spotlight);
    final corner = hitTestSceneRectangleCorner(
      bounds: bounds,
      worldPoint: event.localPosition,
      zoom: 1,
    );
    if (!_draw && corner == null && !bounds.contains(event.localPosition)) {
      return;
    }
    _pointer = event.pointer;
    _gestureTarget = target;
    _gesture = SceneRectangleGesture(
      pointer: event.pointer,
      worldPoint: event.localPosition - _gestureOrigin,
      limit: Size(target.width * 8, target.height * 8),
      snapPolicy: const TerrainPolygonSnapPolicy.halfPixel(),
      neighbors: const [],
      snapToNeighbors: false,
      zoom: 1,
      original: _draw ? null : bounds.shift(-_gestureOrigin),
      corner: corner,
      moving: !_draw && corner == null,
    );
  }

  void _move(PointerMoveEvent event) {
    final gesture = _gesture;
    if (gesture == null) return;
    gesture.update(
      pointer: event.pointer,
      worldPoint: event.localPosition - _gestureOrigin,
      zoom: 1,
    );
    setState(() => _draft = gesture.bounds.shift(_gestureOrigin));
  }

  TutorialSpotlight? get _draftSpotlight {
    final bounds = _draft;
    final target = _gestureTarget;
    if (bounds == null ||
        target == null ||
        bounds.width <= 1 ||
        bounds.height <= 1) {
      return null;
    }
    return TutorialSpotlight(
      shape: widget.spotlight.shape,
      x: ((bounds.left - target.left) / target.width).clamp(-2, 2),
      y: ((bounds.top - target.top) / target.height).clamp(-2, 2),
      width: (bounds.width / target.width).clamp(0.25, 4),
      height: (bounds.height / target.height).clamp(0.25, 4),
    );
  }

  void _finish(int pointer) {
    if (_pointer != pointer) return;
    final value = _draftSpotlight;
    if (value != null) widget.onChanged(value);
    _cancel();
  }

  void _cancel() => setState(() {
    _pointer = null;
    _gesture = null;
    _draft = null;
    _gestureTarget = null;
    _draw = false;
  });

  @override
  void didUpdateWidget(CampaignTutorialSpotlightCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode || oldWidget.target != widget.target) {
      _pointer = null;
      _gesture = null;
      _draft = null;
      _gestureTarget = null;
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<String>(
            value: _device,
            items: [
              for (final name in RunnerPlaytestDevicePresets.devices.keys)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (value) {
              _cancel();
              setState(() => _device = value!);
            },
          ),
          DropdownButton<TutorialSpotlightShape>(
            value: widget.spotlight.shape,
            items: const [
              DropdownMenuItem(
                value: TutorialSpotlightShape.ellipse,
                child: Text('Ellipse / circle'),
              ),
              DropdownMenuItem(
                value: TutorialSpotlightShape.roundedRectangle,
                child: Text('Rounded rectangle'),
              ),
            ],
            onChanged: (shape) => widget.onChanged(
              TutorialSpotlight(
                shape: shape!,
                x: widget.spotlight.x,
                y: widget.spotlight.y,
                width: widget.spotlight.width,
                height: widget.spotlight.height,
              ),
            ),
          ),
          FilterChip(
            label: const Text('Draw spotlight'),
            selected: _draw,
            onSelected: (value) => setState(() => _draw = value),
          ),
          TextButton(
            onPressed: () => widget.onChanged(
              widget.target != CampaignTutorialTarget.movement
                  ? const TutorialSpotlight()
                  : CampaignMovementTutorial.movementIntroduction()
                        .spotlights[tutorialMovementControl(widget.mode)]!,
            ),
            child: const Text('Reset shape'),
          ),
        ],
      ),
      const Text(
        'Drag inside to move; drag a corner to resize. This diagram fits the panel. Play uses your calibrated display size.',
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 260,
        child: FittedBox(
          child: SizedBox(
            width: _size.width,
            height: _size.height,
            child: Listener(
              key: const ValueKey('tutorial_spotlight_canvas'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: (event) => _finish(event.pointer),
              onPointerCancel: (_) => _cancel(),
              child: GestureDetector(
                onPanStart: (_) {},
                onPanUpdate: (_) {},
                child: Stack(
                  key: _surfaceKey,
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: Theme.of(context).colorScheme.surface),
                    if (widget.target.isWorld && widget.worldPreview != null)
                      FittedBox(
                        child: SizedBox(
                          width: 600,
                          height: 270,
                          child: widget.worldPreview,
                        ),
                      ),
                    if ({
                      CampaignTutorialTarget.mobility,
                      CampaignTutorialTarget.primary,
                      CampaignTutorialTarget.projectile,
                    }.contains(widget.target))
                      TapAbilityControl(
                        slot: switch (widget.target) {
                          CampaignTutorialTarget.primary => AbilitySlot.primary,
                          CampaignTutorialTarget.projectile =>
                            AbilitySlot.projectile,
                          _ => AbilitySlot.mobility,
                        },
                        targetKey: _targetKey,
                        enabled: false,
                        onPressed: () {},
                      ),
                    if (widget.target == CampaignTutorialTarget.jump)
                      JumpControl(targetKey: _targetKey, onPressed: () {})
                    else if (widget.target ==
                            CampaignTutorialTarget.resources ||
                        widget.target ==
                            CampaignTutorialTarget.blessingResources)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Column(
                          key: _targetKey,
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ResourceBarsPanel(
                              health: 100,
                              healthMax: 100,
                              ability: 100,
                              abilityMax: 100,
                              stamina: 85,
                              staminaMax: 100,
                              active: false,
                              compact: _size.width - 16 < 584,
                            ),
                            if (widget.target ==
                                CampaignTutorialTarget.blessingResources) ...[
                              const SizedBox(height: 4),
                              const LevelBlessingsHud(
                                blessings: [
                                  LevelBlessingSnapshot(
                                    id: LevelBlessingId.regeneration,
                                    grantedAtTick: 0,
                                  ),
                                ],
                                tick: 0,
                                tickHz: 60,
                              ),
                            ],
                          ],
                        ),
                      )
                    else if (widget.target == CampaignTutorialTarget.runStats)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: RunHudActionsRow(
                          stats: RunStatsPanel(
                            key: _targetKey,
                            distanceMeters: 3,
                            collectibles: 1,
                          ),
                          pause: const HudIconButton(
                            onPressed: null,
                            icon: Icons.pause,
                            tooltip: 'Pause',
                          ),
                          exit: const HudIconButton(
                            onPressed: null,
                            icon: Icons.close,
                            tooltip: 'Exit',
                          ),
                        ),
                      )
                    else if (widget.target == CampaignTutorialTarget.objectives)
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: CampaignObjectivesPanel(
                            key: _targetKey,
                            campaign: const CampaignSnapshot(
                              missionId: 'tutorial_preview',
                              completed: 0,
                              required: 1,
                              failed: false,
                              exitX: 600,
                              exitY: 224,
                              firstCoinRequired: true,
                            ),
                            playerX: 0,
                          ),
                        ),
                      )
                    else if (widget.target == CampaignTutorialTarget.movement)
                      MovementControlPlacement(
                        mode: widget.mode,
                        child: IgnorePointer(
                          child: MovementControl(
                            key: _targetKey,
                            tuning: ControlsTuning.fixed,
                            mode: widget.mode,
                            onMoveAxis: (_) {},
                          ),
                        ),
                      ),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: TutorialVeilPainter(
                          target: _target,
                          spotlight: _draftSpotlight ?? widget.spotlight,
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _HandlesPainter(
                          bounds: () {
                            final target = _target();
                            return target == null
                                ? null
                                : tutorialSpotlightRect(
                                    target,
                                    _draftSpotlight ?? widget.spotlight,
                                  );
                          },
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _HandlesPainter extends CustomPainter {
  _HandlesPainter({required this.bounds, required this.color});
  final Rect? Function() bounds;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = bounds();
    if (rect == null) return;
    canvas.drawRect(
      rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final corner in SceneRectangleCorner.values) {
      canvas.drawCircle(corner.position(rect), 7, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _HandlesPainter oldDelegate) => true;
}
