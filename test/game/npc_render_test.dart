import 'package:rpg_runner/game/components/sprite_anim/ghost_outline_cache.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/playtest/playtest_scenario.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:rpg_runner/game/components/npcs/npc_render_registry.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';
import 'package:rpg_runner/playtest/runner_playtest_appearance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all NPC strips load, mirror and play release/death frames deterministically', () async {
    final registry = NpcRenderRegistry();
    final images = Images();
    addTearDown(images.clearCache);
    await registry.load(images);
    final warmup = UiAssetLifecycle.collectRunStartImagePathsForCharacter(
      PlayerCharacterRegistry.eloise.id,
    );
    expect(warmup, containsAll(registry.assetPaths.toSet()));
    final captured = RunnerPlaytestAppearance(
      parallaxThemes: {},
      terrainMaterials: {},
    ).requiredAssetKeys(scenario: _Scenario(), patterns: []);
    expect(
      captured,
      containsAll(registry.assetPaths.toSet().map((p) => 'assets/images/$p')),
    );
    expect(
      captured,
      contains('assets/images/entities/npc/huntress/spear_move.png'),
    );
    expect(
      captured,
      contains('assets/images/entities/npc/huntress_2/arrow/move.png'),
    );
    expect(warmup, contains('entities/npc/huntress/spear_move.png'));
    expect(warmup, contains('entities/npc/huntress_2/arrow/move.png'));

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFF243249), ui.BlendMode.src);
    for (final id in NpcId.values) {
      final catalog = const NpcCatalog().get(id);
      final entry = registry.entryFor(id)!;
      final sequence = catalog.meleeSequence;
      final abilities = [
        AbilityCatalog.shared.resolve(catalog.attackAbilityId)!,
        if (sequence != null) ...[
          AbilityCatalog.shared.resolve(sequence.openerAbilityId)!,
          AbilityCatalog.shared.resolve(sequence.followUpAbilityId)!,
        ],
      ];
      final abilitiesByAnim = {
        for (final ability in abilities) ability.animKey: ability,
      };
      final states = [
        AnimKey.idle,
        ...abilitiesByAnim.keys,
        AnimKey.hit,
        AnimKey.death,
      ];
      expect(
        entry.animSet.animations.keys,
        containsAll(catalog.renderAnim.sourcesByKey.keys),
      );
      final view = entry.createView();
      await view.onLoad();
      for (final facing in Facing.values) {
        for (final state in states) {
          final ability = abilitiesByAnim[state];
          final frameTicks = ability != null
              ? ability.windupTicks
              : state == AnimKey.death
              ? 999
              : 0;
          view.applySnapshot(
            EntityRenderSnapshot(
              id: 1,
              kind: EntityKind.npc,
              npcId: id,
              pos: const Vec2(0, 0),
              facing: facing,
              artFacingDir: catalog.artFacing,
              anim: state,
              grounded: true,
              animFrame: frameTicks,
            ),
            tickHz: 60,
          );
          expect(view.scale.x, facing == catalog.artFacing ? 1.5 : -1.5);
          expect(view.current, state);
          if (state == AnimKey.death) {
            expect(
              view.animationTicker!.currentIndex,
              catalog.renderAnim.frameCountsByKey[state]! - 1,
            );
          }
          if (ability != null) {
            expect(
              view.animationTicker!.currentIndex,
              ability.windupTicks ~/ 6,
            );
          }
          final column = states.indexOf(state);
          final x = 120.0 + column * 220;
          final y = 95.0 + (id.index * 2 + facing.index) * 115;
          view.position.setValues(x, y);
          view.renderTree(canvas);
          // Body and support guides use the same mirrored source anchor as Core.
          final cx =
              x +
              (facing == catalog.artFacing ? 1 : -1) * catalog.collider.offsetX;
          final paint = ui.Paint()
            ..color = const ui.Color(0x8865E3AE)
            ..style = ui.PaintingStyle.stroke;
          canvas.drawRect(
            ui.Rect.fromCenter(
              center: ui.Offset(cx, y),
              width: catalog.collider.halfX * 2,
              height: catalog.collider.halfY * 2,
            ),
            paint,
          );
          canvas.drawLine(
            ui.Offset(x - 55, y + 27),
            ui.Offset(x + 55, y + 27),
            paint,
          );
        }
      }
      final outlines = GhostOutlineCache();
      addTearDown(outlines.clear);
      view.useGhostStyle(outlines);
      view.update(0);
      expect(view.paint.colorFilter, isNotNull);
    }
    // Optional review artifact; tests do not depend on local output or goldens.
    if (Platform.environment['NPC_RENDER_REVIEW'] == '1') {
      final picture = recorder.endRecording();
      final image = await picture.toImage(1340, 720);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('.tmp/npc_render_review.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    } else {
      recorder.endRecording().dispose();
    }
  });
}

class _Scenario implements PlaytestScenario {
  @override
  int get tickHz => 60;
  @override
  PlayerCharacterDefinition get playerCharacter =>
      PlayerCharacterRegistry.eloise;
}
