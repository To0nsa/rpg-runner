import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:flutter/material.dart';
import 'package:rpg_runner/playtest.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';

import 'campaign_localized_text_fields.dart';
import 'campaign_tutorial_hud_picker.dart';
import 'campaign_tutorial_world_target_picker.dart';
import 'campaign_tutorial_spotlight_canvas.dart';

/// One local draft for all three pages; Apply returns one revision-guarded edit.
class CampaignStepsTutorialDialog extends StatefulWidget {
  const CampaignStepsTutorialDialog({
    super.key,
    required this.tutorial,
    required this.missionChunkIds,
    this.worldPreviewBuilder,
    this.shrines = const [],
    this.enemies = const [],
  });
  final CampaignSteppedTutorial tutorial;
  final List<String> missionChunkIds;
  final Widget Function(String missionChunkId)? worldPreviewBuilder;
  final List<CampaignTutorialShrine> shrines;
  final List<CampaignEnemySource> enemies;

  @override
  State<CampaignStepsTutorialDialog> createState() => _StepsDialogState();
}

class _StepsDialogState extends State<CampaignStepsTutorialDialog> {
  final _form = GlobalKey<FormState>();
  CampaignJumpTutorial? get _jump => widget.tutorial is CampaignJumpTutorial
      ? widget.tutorial as CampaignJumpTutorial
      : null;
  CampaignBlessingTutorial? get _blessing =>
      widget.tutorial is CampaignBlessingTutorial
      ? widget.tutorial as CampaignBlessingTutorial
      : null;
  CampaignCombatTutorial? get _combat =>
      widget.tutorial is CampaignCombatTutorial
      ? widget.tutorial as CampaignCombatTutorial
      : null;
  late String? _enemyId = widget.enemies
      .where(
        (e) =>
            e.missionChunkId == _combat?.missionChunkId &&
            e.marker.salt == _combat?.markerSalt,
      )
      .firstOrNull
      ?.id;
  CampaignEnemySource? get _enemy =>
      widget.enemies.where((e) => e.id == _enemyId).firstOrNull;
  late final _practiceHint = Map<String, String>.of(
    _combat?.practiceHint ?? {},
  );
  final _practiceKey = GlobalKey<CampaignLocalizedTextFieldsState>();
  late String? _shrineId = _blessing?.shrineId;
  CampaignTutorialShrine? get _shrine =>
      widget.shrines.where((s) => s.id == _shrineId).firstOrNull;
  late double _distance =
      _combat?.approachDistance ?? _blessing?.approachDistance ?? 96;

  final _titleKeys = List.generate(
    3,
    (_) => GlobalKey<CampaignLocalizedTextFieldsState>(),
  );
  final _instructionKeys = List.generate(
    3,
    (_) => GlobalKey<CampaignLocalizedTextFieldsState>(),
  );
  late final _titles = [
    for (final step in widget.tutorial.steps)
      Map<String, String>.of(step.title),
  ];
  late final _instructions = [
    for (final step in widget.tutorial.steps)
      Map<String, String>.of(step.instruction),
  ];
  late final _spotlights = [
    for (final step in widget.tutorial.steps) step.spotlight,
  ];
  late final _reveals = [
    for (final step in widget.tutorial.steps) {...step.reveals},
  ];
  late final _bounds = [
    for (final value in [
      _jump?.obstacle.x ?? 0,
      _jump?.obstacle.y ?? 0,
      _jump?.obstacle.width ?? 1,
      _jump?.obstacle.height ?? 1,
    ])
      TextEditingController(text: value.toString()),
  ];
  late String _chunk =
      _combat?.missionChunkId ??
      _jump?.missionChunkId ??
      _shrine?.missionChunkId ??
      '';
  late String _name = widget.tutorial.name;
  late bool _enabled = widget.tutorial.enabled;
  int _page = 0;
  String? _error;

  @override
  void dispose() {
    for (final controller in _bounds) {
      controller.dispose();
    }
    super.dispose();
  }

  Rect? get _target {
    if (_combat != null) {
      final e = _enemy;
      if (e == null) return null;
      final body = const EnemyCatalog().get(e.marker.enemyId).collider;
      return Rect.fromLTWH(
        e.position.x + body.offsetX - body.halfX,
        e.position.y + body.offsetY - body.halfY,
        body.halfX * 2,
        body.halfY * 2,
      );
    }
    if (_blessing != null) {
      final b = _shrine?.bounds;
      return b == null ? null : Rect.fromLTWH(b.x, b.y, b.width, b.height);
    }
    double value(int index, double fallback) {
      final parsed = double.tryParse(_bounds[index].text);
      return parsed != null && parsed.isFinite ? parsed : fallback;
    }

    return Rect.fromLTWH(
      value(0, 0).clamp(0, 599),
      value(1, 0).clamp(0, 269),
      value(2, 1).clamp(1, 600),
      value(3, 1).clamp(1, 270),
    );
  }

  void _apply() {
    if (!_form.currentState!.validate()) {
      _practiceKey.currentState?.revealFirstError();
      for (var i = 0; i < 3; i++) {
        if (_titles[i].values.any((v) => v.trim().isEmpty || v.length > 120) ||
            _instructions[i].values.any(
              (v) => v.trim().isEmpty || v.length > 500,
            )) {
          setState(() => _page = i);
          _titleKeys[i].currentState!.revealFirstError();
          _instructionKeys[i].currentState!.revealFirstError();
          break;
        }
      }
      return;
    }
    _form.currentState!.save();
    try {
      final result = decodeCampaignTutorial(
        widget.tutorial.toJson()..addAll({
          'name': _name,
          'enabled': _enabled,
          if (_combat != null) ...{
            'missionChunkId': _enemy?.missionChunkId,
            'markerSalt': _enemy?.marker.salt,
            'approachDistance': _distance,
            'practiceHint': _practiceHint,
          },
          if (_blessing != null) ...{
            'shrineId': _shrineId,
            'approachDistance': _distance,
          },
          if (_jump != null) ...{
            'missionChunkId': _chunk,
            'obstacle': {
              for (var i = 0; i < 4; i++)
                ['x', 'y', 'width', 'height'][i]: double.parse(_bounds[i].text),
            },
          },
          'steps': [
            for (var i = 0; i < 3; i++)
              {
                'target': widget.tutorial.steps[i].target.name,
                'title': _titles[i],
                'instruction': _instructions[i],
                'spotlight': _spotlights[i].toJson(),
                'reveals': _reveals[i].map((e) => e.name).toList(),
              },
          ],
        }),
      );
      Navigator.of(context).pop(result);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      _combat != null
          ? 'Projectiles and sword'
          : _blessing == null
          ? 'Obstacles, jump and resources'
          : 'Blessing objective and regeneration',
    ),
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
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Sequence name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required.' : null,
                onSaved: (v) => _name = v!.trim(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              if (_jump != null)
                DropdownButtonFormField<String>(
                  initialValue: _chunk,
                  decoration: const InputDecoration(
                    labelText: 'Start when entering mission chunk',
                  ),
                  items: [
                    for (var i = 0; i < widget.missionChunkIds.length; i++)
                      DropdownMenuItem(
                        value: widget.missionChunkIds[i],
                        child: Text('${i + 1}. ${widget.missionChunkIds[i]}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _chunk = v!),
                ),
              if (_combat != null) ...[
                DropdownButtonFormField<String>(
                  initialValue: _enemyId,
                  decoration: const InputDecoration(labelText: 'Enemy marker'),
                  items: [
                    for (final e in widget.enemies)
                      DropdownMenuItem(
                        value: e.id,
                        child: Text('${e.id} · ${e.missionChunkId}'),
                      ),
                  ],
                  validator: (id) =>
                      widget.enemies.any(
                        (e) => e.id == id && e.marker.chancePercent == 100,
                      )
                      ? null
                      : 'Select a guaranteed enemy marker.',
                  onChanged: (id) => setState(() {
                    _enemyId = id;
                    _chunk = _enemy?.missionChunkId ?? '';
                  }),
                ),
                CampaignTutorialApproachDistanceField(
                  subject: 'enemy',
                  distance: _distance,
                  onSaved: (v) => _distance = v,
                ),
                CampaignLocalizedTextFields(
                  key: _practiceKey,
                  title: _practiceHint,
                  titleLabel: 'Practice hint while projectiles are locked',
                  titleMaxLength: 250,
                  titleMaxLines: 3,
                  onTitleChanged: (language, value) =>
                      _practiceHint[language] = value,
                ),
              ],
              if (_blessing != null) ...[
                DropdownButtonFormField<String>(
                  initialValue: _shrine?.id,
                  decoration: const InputDecoration(
                    labelText: 'Objective shrine marker',
                  ),
                  items: [
                    for (final shrine in widget.shrines)
                      DropdownMenuItem(
                        value: shrine.id,
                        child: Text('${shrine.id} · ${shrine.missionChunkId}'),
                      ),
                  ],
                  validator: (id) => widget.shrines.any((s) => s.id == id)
                      ? null
                      : 'Select an available shrine marker.',
                  onChanged: (id) => setState(() {
                    _shrineId = id;
                    _chunk = _shrine?.missionChunkId ?? '';
                  }),
                ),
                CampaignTutorialApproachDistanceField(
                  subject: 'shrine',
                  distance: _distance,
                  onSaved: (v) => _distance = v,
                ),
              ],
              Text(
                _combat != null
                    ? 'Next introduces Projectile. A fresh press fires; the real launch locks further shots. Sword is introduced at melee reach. Its real strike unlocks Projectile. Dead targets and alternate builds release both controls without trapping the player.'
                    : _blessing == null
                    ? 'One paused sequence. Next advances the first two steps; a fresh Jump resumes play after resources. Reveals stay visible.'
                    : 'Movement resumes after the objective page. The real shrine activation opens the blessing page. Next explains regeneration; fresh movement resumes. Apply also selects this shrine as the required mission objective.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < 3; i++)
                    ChoiceChip(
                      label: Text(
                        (_combat != null
                            ? ['1. Enemy', '2. Projectile', '3. Sword']
                            : _blessing == null
                            ? ['1. Obstacle', '2. Jump', '3. Resources']
                            : [
                                '1. Objective',
                                '2. Blessing',
                                '3. Regeneration',
                              ])[i],
                      ),
                      selected: _page == i,
                      onSelected: (_) => setState(() => _page = i),
                    ),
                ],
              ),
              for (var i = 0; i < 3; i++)
                Offstage(
                  offstage: _page != i,
                  child: ExcludeFocus(
                    excluding: _page != i,
                    child: Column(
                      children: [
                        CampaignLocalizedTextFields(
                          key: _titleKeys[i],
                          title: _titles[i],
                          titleLabel: 'Card title',
                          onTitleChanged: (language, value) =>
                              _titles[i][language] = value,
                        ),
                        CampaignLocalizedTextFields(
                          key: _instructionKeys[i],
                          title: _instructions[i],
                          titleLabel: 'Instruction',
                          onTitleChanged: (language, value) =>
                              _instructions[i][language] = value,
                          titleMaxLength: 500,
                          titleMaxLines: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              CampaignTutorialHudPicker(
                title: 'Reveal at this step and keep visible',
                value: _reveals[_page],
                requiredElements: _combat != null
                    ? {
                        if (_page == 1) TutorialHudElement.projectile,
                        if (_page == 2) TutorialHudElement.primary,
                      }
                    : _blessing == null
                    ? {
                        if (_page == 1) TutorialHudElement.jump,
                        if (_page == 2) TutorialHudElement.resources,
                      }
                    : {
                        if (_page == 0) ...{
                          TutorialHudElement.objectives,
                          TutorialHudElement.jump,
                        },
                        if (_page == 2) ...{
                          TutorialHudElement.resources,
                          TutorialHudElement.blessings,
                        },
                      },
                onChanged: (v) => setState(() => _reveals[_page] = v),
              ),
              if (_jump != null && _page == 0) ...[
                const Text(
                  'Obstacle target bounds in chunk coordinates. Draw or adjust the spotlight below; this never edits terrain.',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < 4; i++)
                      SizedBox(
                        width: 145,
                        child: TextFormField(
                          controller: _bounds[i],
                          decoration: InputDecoration(
                            labelText: [
                              'Target X',
                              'Target Y',
                              'Target width',
                              'Target height',
                            ][i],
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            return n == null ||
                                    !n.isFinite ||
                                    n < (i < 2 ? 0 : 1)
                                ? 'Enter a valid number.'
                                : null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                  ],
                ),
              ],
              CampaignTutorialSpotlightCanvas(
                key: ValueKey((_page, _shrineId, _chunk)),
                mode: MovementControlMode.arrows,
                target: widget.tutorial.steps[_page].target,
                spotlight: _spotlights[_page],
                onChanged: (v) => setState(() => _spotlights[_page] = v),
                worldTarget: widget.tutorial.targetAt(_page).isWorld
                    ? _target
                    : null,
                worldPreview:
                    widget.tutorial.targetAt(_page).isWorld && _chunk.isNotEmpty
                    ? widget.worldPreviewBuilder?.call(_chunk)
                    : null,
              ),
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
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _apply, child: const Text('Apply')),
    ],
  );
}
