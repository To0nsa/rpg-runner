import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/teleport_destination_cues.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/util/vec2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('destination cue draws at the captured mark and disappears with the snapshot', () async {
    final cues = TeleportDestinationCues()
      ..entities = const [
        EntityRenderSnapshot(
          id: 1,
          kind: EntityKind.enemy,
          pos: Vec2(20, 40),
          facing: Facing.right,
          anim: AnimKey.teleportOut,
          grounded: true,
          size: Vec2(18, 54),
          teleportDestination: Vec2(80, 40),
        ),
      ];
    Future<int> alphaAt(int x, int y) async {
      final recorder = PictureRecorder();
      cues.render(Canvas(recorder));
      final picture = recorder.endRecording();
      final image = await picture.toImage(120, 90);
      final bytes = (await image.toByteData())!;
      final alpha = bytes.getUint8((y * 120 + x) * 4 + 3);
      image.dispose();
      picture.dispose();
      return alpha;
    }

    expect(await alphaAt(80, 40), greaterThan(0));
    expect(await alphaAt(20, 40), 0);
    cues.entities = const [];
    expect(await alphaAt(80, 40), 0);
  });
}
