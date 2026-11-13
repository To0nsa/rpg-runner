import 'package:flutter/material.dart';
import 'package:rpg_runner/playtest.dart';
import 'package:runner_content_pipeline/campaign_tutorial.dart';
import 'package:runner_core/terrain/water_region.dart';
import 'package:runner_core/track/chunk_pattern.dart';

import 'campaign_localized_text_fields.dart';
import 'campaign_tutorial_spotlight_canvas.dart';
import 'campaign_tutorial_hud_picker.dart';
import 'campaign_tutorial_water_target_picker.dart';
import 'campaign_tutorial_decoration_picker.dart';
import 'campaign_tutorial_world_target_picker.dart';
import 'campaign_tutorial_position_picker.dart';

class CampaignTutorialDialog extends StatefulWidget {
  const CampaignTutorialDialog({
    super.key,
    required this.tutorial,
    this.waterRegionsByChunk = const {},
    this.spritesByChunk = const {},
    this.gapsByChunk = const {},
    this.platformsByChunk = const {},
    this.missionChunkIds = const [],
    this.worldPreviewBuilder,
  });
  final CampaignTutorialSequence tutorial;
  final List<String> missionChunkIds;
  final Map<String, List<WaterRegionData>> waterRegionsByChunk;
  final Map<String, List<ChunkVisualSpriteRel>> spritesByChunk;
  final Map<String, List<CampaignTutorialGap>> gapsByChunk;
  final Map<String, List<CampaignTutorialPlatform>> platformsByChunk;
  final Widget Function(String missionChunkId)? worldPreviewBuilder;
  @override
  State<CampaignTutorialDialog> createState() => _DialogState();
}

class _DialogState extends State<CampaignTutorialDialog> {
  final _form = GlobalKey<FormState>();
  final _titleKey = GlobalKey<CampaignLocalizedTextFieldsState>();
  final _instructionKeys = {
    for (final c in TutorialMovementControl.values)
      c: GlobalKey<CampaignLocalizedTextFieldsState>(),
  };
  late final _title = Map<String, String>.of(widget.tutorial.title);
  bool get _isPanel => widget.tutorial is CampaignPanelTutorial;
  late final _instructions = {
    for (final entry
        in (widget.tutorial is CampaignMovementTutorial
                ? (widget.tutorial as CampaignMovementTutorial).instructions
                : <TutorialMovementControl, Map<String, String>>{})
            .entries)
      entry.key: Map<String, String>.of(entry.value),
  };
  late final _spotlights = widget.tutorial is CampaignMovementTutorial
      ? Map.of((widget.tutorial as CampaignMovementTutorial).spotlights)
      : <TutorialMovementControl, TutorialSpotlight>{};
  final _panelKey = GlobalKey<CampaignLocalizedTextFieldsState>();
  late final _panelText = _isPanel
      ? Map<String, String>.of(
          (widget.tutorial as CampaignPanelTutorial).instruction,
        )
      : <String, String>{};
  late TutorialSpotlight _panelSpotlight = _isPanel
      ? (widget.tutorial as CampaignPanelTutorial).spotlight
      : const TutorialSpotlight();
  late Set<TutorialHudElement> _reveals = {...widget.tutorial.reveals};
  late String _name = widget.tutorial.name;
  late bool _enabled = widget.tutorial.enabled;
  TutorialMovementControl _control = TutorialMovementControl.arrows;
  String? _error;
  late String? _worldChunk = widget.tutorial.missionChunkId;
  late double _triggerX = widget.tutorial is CampaignMobilityTutorial
      ? (widget.tutorial as CampaignMobilityTutorial).triggerX
      : 0;
  late String? _waterRegion = widget.tutorial is CampaignWaterTutorial
      ? (widget.tutorial as CampaignWaterTutorial).waterRegionId
      : widget.tutorial is CampaignDecorationTutorial
      ? (widget.tutorial as CampaignDecorationTutorial).waterRegionId
      : null;
  late String? _decorationKey = widget.tutorial is CampaignDecorationTutorial
      ? (widget.tutorial as CampaignDecorationTutorial).decorationPrefabKey
      : null;
  late String? _platformKey = widget.tutorial is CampaignPlatformTutorial
      ? (widget.tutorial as CampaignPlatformTutorial).platformPrefabKey
      : null;
  CampaignTutorialPlatform? get _selectedPlatform => widget
      .platformsByChunk[_worldChunk]
      ?.where((p) => p.prefabKey == _platformKey)
      .firstOrNull;
  late String? _nearGround = widget.tutorial is CampaignGapTutorial
      ? (widget.tutorial as CampaignGapTutorial).nearGroundShapeId
      : null;
  late String? _farGround = widget.tutorial is CampaignGapTutorial
      ? (widget.tutorial as CampaignGapTutorial).farGroundShapeId
      : null;
  CampaignTutorialGap? get _selectedGap => widget.gapsByChunk[_worldChunk]
      ?.where(
        (g) =>
            g.nearGroundShapeId == _nearGround &&
            g.farGroundShapeId == _farGround,
      )
      .firstOrNull;
  void _selectGap(CampaignTutorialGap? gap) {
    _nearGround = gap?.nearGroundShapeId;
    _farGround = gap?.farGroundShapeId;
  }

  List<ChunkVisualSpriteRel> get _sprites =>
      widget.spritesByChunk[_worldChunk] ?? const [];
  bool get _hasWaterReference =>
      widget.tutorial is CampaignWaterTutorial ||
      widget.tutorial is CampaignDecorationTutorial;
  late double _approachDistance = widget.tutorial is CampaignWaterTutorial
      ? (widget.tutorial as CampaignWaterTutorial).approachDistance
      : widget.tutorial is CampaignGapTutorial
      ? (widget.tutorial as CampaignGapTutorial).approachDistance
      : widget.tutorial is CampaignPlatformTutorial
      ? (widget.tutorial as CampaignPlatformTutorial).approachDistance
      : 20;
  WaterRegionData? get _selectedWater => widget.waterRegionsByChunk[_worldChunk]
      ?.where((water) => water.id == _waterRegion)
      .firstOrNull;
  Rect? get _waterBounds {
    final water = _selectedWater;
    return water == null
        ? null
        : Rect.fromLTWH(
            water.x.toDouble(),
            water.y.toDouble(),
            water.width.toDouble(),
            water.height.toDouble(),
          );
  }

  Rect? get _worldBounds {
    if (widget.tutorial is CampaignPlatformTutorial) {
      final b = _selectedPlatform?.bounds;
      return b == null ? null : Rect.fromLTWH(b.x, b.y, b.width, b.height);
    }
    if (widget.tutorial is CampaignGapTutorial) {
      final b = _selectedGap?.bounds;
      return b == null ? null : Rect.fromLTWH(b.x, b.y, b.width, b.height);
    }
    if (widget.tutorial is! CampaignDecorationTutorial) return _waterBounds;
    final sprite = campaignTutorialDecorations(_sprites)
        .where((s) => s.prefabKey == _decorationKey)
        .firstOrNull;
    if (sprite == null) return null;
    final bounds = campaignTutorialSpriteBounds(sprite);
    return Rect.fromLTWH(bounds.x, bounds.y, bounds.width, bounds.height);
  }

  void _apply() {
    if (!_form.currentState!.validate()) {
      _titleKey.currentState!.revealFirstError();
      _panelKey.currentState?.revealFirstError();
      for (final control in _instructions.keys) {
        final text = _instructions[control]!;
        if (text.values.any(
          (value) => value.trim().isEmpty || value.length > 500,
        )) {
          setState(() => _control = control);
          _instructionKeys[control]!.currentState!.revealFirstError();
          break;
        }
      }
      return;
    }
    _form.currentState!.save();
    try {
      final tutorial = decodeCampaignTutorial(
        widget.tutorial.toJson()..addAll({
          'name': _name,
          'enabled': _enabled,
          'title': _title,
          'reveals': _reveals.map((e) => e.name).toList(),
          if (widget.tutorial is CampaignMobilityTutorial) ...{
            'missionChunkId': _worldChunk,
            'triggerX': _triggerX,
          },
          if (widget.tutorial is CampaignPlatformTutorial) ...{
            'missionChunkId': _worldChunk,
            'platformPrefabKey': _platformKey,
            'approachDistance': _approachDistance,
          },
          if (widget.tutorial is CampaignGapTutorial) ...{
            'missionChunkId': _worldChunk,
            'nearGroundShapeId': _nearGround,
            'farGroundShapeId': _farGround,
            'approachDistance': _approachDistance,
          },
          if (_hasWaterReference) ...{
            'missionChunkId': _worldChunk,
            'waterRegionId': _waterRegion,
            if (widget.tutorial is CampaignWaterTutorial)
              'approachDistance': _approachDistance,
            if (widget.tutorial is CampaignDecorationTutorial)
              'decorationPrefabKey': _decorationKey,
          },
          if (_isPanel) ...{
            'instruction': _panelText,
            'spotlight': _panelSpotlight.toJson(),
          } else ...{
            'instructions': {
              for (final entry in _instructions.entries)
                entry.key.name: entry.value,
            },
            'spotlights': {
              for (final entry in _spotlights.entries)
                entry.key.name: entry.value.toJson(),
            },
          },
        }),
      );
      Navigator.of(context).pop(tutorial);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(switch (widget.tutorial.target) {
      CampaignTutorialTarget.movement => 'Movement introduction',
      CampaignTutorialTarget.objectives => 'Objectives introduction',
      CampaignTutorialTarget.runStats => 'First coin',
      CampaignTutorialTarget.water => 'Water introduction',
      CampaignTutorialTarget.gap => 'Gap crossing',
      CampaignTutorialTarget.platform => 'Platforms',
      CampaignTutorialTarget.decoration => 'Decorations and obstacles',
      CampaignTutorialTarget.jump => 'First swim',
      CampaignTutorialTarget.mobility => 'Mobility: Dash',
      _ => throw StateError(
        'Multi-step lessons use CampaignStepsTutorialDialog.',
      ),
    }),
    content: SizedBox(
      width: 820,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Sequence name'),
                maxLength: 120,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required.' : null,
                onSaved: (value) => _name = value!.trim(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              Text(switch (widget.tutorial.trigger) {
                CampaignTutorialTrigger.enemyApproached => 'Enemy approach, projectile practice, then sword at melee reach.',
                CampaignTutorialTrigger.mobilityReached => 'On dry ground at or beyond the trigger, once Dash is ready. A fresh Mobility press resumes play and performs the dash. Other equipped mobility skills are revealed without this Dash-specific card.',
                CampaignTutorialTrigger.missionStart => 'At mission start. Using movement dismisses the explanation and starts gameplay.',
                CampaignTutorialTrigger.movementStarted => 'After a short walk in either direction. Play pauses to introduce objectives; use fresh movement to continue.',
                CampaignTutorialTrigger.firstCoinCollected => 'After the first collected coin. Play pauses until a fresh movement gesture; existing holds are cancelled.',
                CampaignTutorialTrigger.chunkEntered =>
                  'On entry to the authored mission chunk.',
                CampaignTutorialTrigger.waterApproached => 'Before the selected water, including airborne approaches. Fresh movement resumes play.',
                CampaignTutorialTrigger.firstSwimming => 'On the first actual swim in any pool when a stroke is available. Fresh Jump resumes and swims upward. Skipping water never blocks later lessons.',
                CampaignTutorialTrigger.blessingApproached =>
                  'After the shrine objective approach and real activation.',
                CampaignTutorialTrigger.platformApproached => 'On safe ground before the selected platform. Fresh movement resumes; jump through it and land on top. An airborne bypass is not interrupted.',
                CampaignTutorialTrigger.gapApproached => 'On safe ground before the selected gap. Fresh movement resumes; time the jump yourself. An early crossing skips this explanation.',
                CampaignTutorialTrigger.waterCleared => 'Once grounded beyond the selected water, whether swimming or jumping across. Fresh movement resumes play.',
              }),
              if (widget.tutorial is CampaignMobilityTutorial)
                CampaignTutorialPositionPicker(
                  chunks: widget.missionChunkIds,
                  chunkId: _worldChunk,
                  x: _triggerX,
                  onChunkChanged: (value) =>
                      setState(() => _worldChunk = value),
                  onXChanged: (value) => setState(() => _triggerX = value),
                  previewBuilder: widget.worldPreviewBuilder,
                ),
              if (_hasWaterReference)
                CampaignTutorialWaterTargetPicker(
                  waterRegionsByChunk: widget.waterRegionsByChunk,
                  chunkId: _worldChunk,
                  waterId: _waterRegion,
                  approachDistance: widget.tutorial is CampaignWaterTutorial
                      ? _approachDistance
                      : null,
                  onChunkChanged: (id) => setState(() {
                    _worldChunk = id;
                    _waterRegion =
                        widget.waterRegionsByChunk[id]?.firstOrNull?.id;
                    _decorationKey = null;
                  }),
                  onWaterChanged: (id) => setState(() => _waterRegion = id),
                  onDistanceSaved: (distance) => _approachDistance = distance,
                ),
              if (widget.tutorial is CampaignPlatformTutorial) ...[
                CampaignTutorialWorldTargetPicker<CampaignTutorialPlatform>(
                  choicesByChunk: widget.platformsByChunk,
                  chunkId: _worldChunk,
                  target: _selectedPlatform,
                  chunkLabel: 'Mission chunk with platforms',
                  targetLabel: 'Platform',
                  describe: (p) => p.prefabKey,
                  onChunkChanged: (id) => setState(() {
                    _worldChunk = id;
                    _platformKey =
                        widget.platformsByChunk[id]?.firstOrNull?.prefabKey;
                  }),
                  onTargetChanged: (p) =>
                      setState(() => _platformKey = p?.prefabKey),
                ),
                CampaignTutorialApproachDistanceField(
                  subject: 'platform',
                  distance: _approachDistance,
                  onSaved: (d) => _approachDistance = d,
                ),
              ],
              if (widget.tutorial is CampaignGapTutorial) ...[
                CampaignTutorialWorldTargetPicker<CampaignTutorialGap>(
                  choicesByChunk: widget.gapsByChunk,
                  chunkId: _worldChunk,
                  target: _selectedGap,
                  chunkLabel: 'Mission chunk with a dry gap',
                  targetLabel: 'Gap banks',
                  describe: (g) =>
                      '${g.nearGroundShapeId} → ${g.farGroundShapeId} · ${g.width} world units',
                  onChunkChanged: (id) => setState(() {
                    _worldChunk = id;
                    _selectGap(widget.gapsByChunk[id]?.firstOrNull);
                  }),
                  onTargetChanged: (g) => setState(() => _selectGap(g)),
                ),
                CampaignTutorialApproachDistanceField(
                  subject: 'gap',
                  distance: _approachDistance,
                  onSaved: (d) => _approachDistance = d,
                ),
              ],
              if (widget.tutorial is CampaignDecorationTutorial)
                CampaignTutorialDecorationPicker(
                  sprites: _sprites,
                  prefabKey: _decorationKey,
                  onChanged: (value) => setState(() => _decorationKey = value),
                ),
              CampaignTutorialHudPicker(
                title: 'Reveal and keep visible',
                value: _reveals,
                requiredElements: switch (widget.tutorial.target) {
                  CampaignTutorialTarget.mobility => {
                    TutorialHudElement.mobility,
                  },
                  CampaignTutorialTarget.movement => {
                    TutorialHudElement.movement,
                  },
                  CampaignTutorialTarget.objectives => {
                    TutorialHudElement.objectives,
                  },
                  CampaignTutorialTarget.runStats => {
                    TutorialHudElement.runStats,
                  },
                  CampaignTutorialTarget.jump => {
                    TutorialHudElement.jump,
                    TutorialHudElement.resources,
                  },
                  CampaignTutorialTarget.platform ||
                  CampaignTutorialTarget.gap ||
                  CampaignTutorialTarget.water ||
                  CampaignTutorialTarget.decoration => {},
                  _ => throw StateError('Use the multi-step dialog.'),
                },
                onChanged: (value) => setState(() => _reveals = value),
              ),
              CampaignLocalizedTextFields(
                key: _titleKey,
                title: _title,
                titleLabel: 'Card title',
              ),
              const SizedBox(height: 12),
              if (_isPanel) ...[
                CampaignLocalizedTextFields(
                  key: _panelKey,
                  title: _panelText,
                  titleLabel: 'Instruction',
                  titleMaxLength: 500,
                  titleMaxLines: 5,
                ),
                CampaignTutorialSpotlightCanvas(
                  key: ValueKey((
                    _worldChunk,
                    _waterRegion,
                    _decorationKey,
                    _nearGround,
                    _farGround,
                    _platformKey,
                  )),
                  target: widget.tutorial.target,
                  mode: MovementControlMode.arrows,
                  spotlight: _panelSpotlight,
                  onChanged: (value) => setState(() => _panelSpotlight = value),
                  worldTarget: _worldBounds,
                  worldPreview:
                      widget.tutorial.target.isWorld && _worldChunk != null
                      ? widget.worldPreviewBuilder?.call(_worldChunk!)
                      : null,
                ),
              ] else ...[
                DropdownButtonFormField<TutorialMovementControl>(
                  initialValue: _control,
                  key: ValueKey(_control),
                  decoration: const InputDecoration(
                    labelText: 'Control variant',
                  ),
                  items: [
                    for (final control in TutorialMovementControl.values)
                      DropdownMenuItem(
                        value: control,
                        child: Text(_label(control)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _control = value!),
                ),
                for (final control in TutorialMovementControl.values)
                  Offstage(
                    offstage: _control != control,
                    child: ExcludeFocus(
                      excluding: _control != control,
                      child: CampaignLocalizedTextFields(
                        key: _instructionKeys[control],
                        title: _instructions[control]!,
                        titleLabel: 'Instruction',
                        titleMaxLength: 500,
                        titleMaxLines: 3,
                        onTitleChanged: (language, value) =>
                            _instructions[control]![language] = value,
                      ),
                    ),
                  ),
                if (_control != TutorialMovementControl.keyboard)
                  CampaignTutorialSpotlightCanvas(
                    mode: switch (_control) {
                      TutorialMovementControl.arrows =>
                        MovementControlMode.arrows,
                      TutorialMovementControl.fixedJoystick =>
                        MovementControlMode.fixedJoystick,
                      _ => MovementControlMode.joystick,
                    },
                    spotlight: _spotlights[_control]!,
                    onChanged: (value) =>
                        setState(() => _spotlights[_control] = value),
                  )
                else
                  const Text(
                    'The keyboard variant shows the card without a touch-control spotlight.',
                  ),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _apply, child: const Text('Apply')),
    ],
  );
}

String _label(TutorialMovementControl control) => switch (control) {
  TutorialMovementControl.arrows => 'Arrows',
  TutorialMovementControl.fixedJoystick => 'Fixed joystick',
  TutorialMovementControl.floatingJoystick => 'Floating joystick',
  TutorialMovementControl.keyboard => 'Keyboard / mobile HUD hidden',
};
