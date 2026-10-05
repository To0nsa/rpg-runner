import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/debug/combat_capsule_overlay.dart';
import 'package:rpg_runner/game/components/sprite_anim/deterministic_anim_view.dart';
import 'package:rpg_runner/game/components/sprite_anim/sprite_anim_set.dart';
import 'package:runner_core/combat/combat_geometry.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/util/vec2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'debug rendering includes oriented rounded ends without AABB inflation',
    () async {
      final overlay = CombatCapsuleOverlay(
        paint: ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      overlay.capsules = const [CombatCapsule(20, 10, 20, 30, 5)];
      final recorder = ui.PictureRecorder();
      overlay.render(ui.Canvas(recorder));
      final picture = recorder.endRecording();
      final image = await picture.toImage(40, 40);
      final bytes = (await image.toByteData())!;
      int alpha(int x, int y) => bytes.getUint8((y * 40 + x) * 4 + 3);
      expect(alpha(20, 7), greaterThan(0));
      expect(alpha(20, 33), greaterThan(0));
      expect(alpha(10, 20), 0);
      expect(alpha(20, 37), 0);
      image.dispose();
      picture.dispose();
    },
  );

  test(
    'snapshot pose angle and frame stay fixed between simulation ticks',
    () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1, 1);
      final set = SpriteAnimSet(
        animations: {
          AnimKey.strike: SpriteAnimation([
            for (var i = 0; i < 6; i++)
              SpriteAnimationFrame(Sprite(image), .06),
          ]),
        },
        stepTimeSecondsByKey: const {AnimKey.strike: .06},
        oneShotKeys: const {AnimKey.strike},
        frameSize: Vector2.all(1),
      );
      final view = DeterministicAnimView(animSet: set, initial: AnimKey.strike);
      view.applySnapshot(
        const EntityRenderSnapshot(
          id: 1,
          kind: EntityKind.player,
          pos: Vec2(0, 0),
          facing: Facing.right,
          anim: AnimKey.strike,
          grounded: true,
          animFrame: 8,
          rotationRad: -math.pi / 2,
        ),
        tickHz: 60,
      );
      expect(view.animationTicker!.currentIndex, 2);
      view.update(.5);
      expect(view.animationTicker!.currentIndex, 2);
      expect(view.angle, -math.pi / 2);
      image.dispose();
      picture.dispose();
    },
  );
}
