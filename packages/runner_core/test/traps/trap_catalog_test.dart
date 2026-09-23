import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_geometry.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';
import 'package:runner_core/traps/trap_validation.dart';
import 'package:test/test.dart';

void main() {
  test('reviewed GIF sequences retain cumulative duration and warning', () {
    for (final (id, count, milliseconds, warningMs, sheetWidth, sheetHeight)
        in [
          (TrapId.spike, 27, 2520, 700, 1920, 256),
          (TrapId.swingingAxe, 51, 9380, 800, 2816, 512),
          (TrapId.poisonDarts, 8, 1000, 500, 1536, 1152),
        ]) {
      final def = TrapCatalog.get(id);
      expect(def.frames, hasLength(count));
      expect(def.durationMs, milliseconds);
      for (final hz in [30, 60, 120]) {
        final duration = def.durationTicks(hz) * 1000 / hz;
        expect(duration, greaterThanOrEqualTo(milliseconds));
        expect(duration - milliseconds, lessThan(1000 / hz));
        expect(
          def.firstHarmfulTick(hz) * 1000 / hz,
          greaterThanOrEqualTo(warningMs),
        );
        expect(def.cooldownTicks(hz), hz);
        for (var i = 0; i < def.frames.length; i++) {
          expect(def.frameAtTick(def.frameStartTick(i, hz), hz), i);
        }
      }
      for (final f in def.frames) {
        expect(f.source.x + f.source.width, lessThanOrEqualTo(sheetWidth));
        expect(f.source.y + f.source.height, lessThanOrEqualTo(sheetHeight));
      }
    }
    expect(
      TrapCatalog.get(TrapId.poisonDarts).frames.where((f) => f.firesDart),
      hasLength(1),
    );
  });

  test('bounds cover mirrored art, trigger and full damage envelopes', () {
    for (final id in TrapId.values) {
      for (final facing
          in id == TrapId.spike ? [Facing.right] : Facing.values) {
        final placement = TrapPlacement(
          trapId: id,
          x: 400,
          y: 128,
          facing: facing,
          trigger: TrapCatalog.get(id).defaultTrigger,
        );
        validateTrapPlacements([placement], chunkWidth: 960, chunkHeight: 320);
        expect(
          () => validateTrapPlacements(
            [placement.copyWith(x: 0)],
            chunkWidth: 960,
            chunkHeight: 320,
          ),
          throwsArgumentError,
        );
        expect(
          () => validateTrapPlacements(
            [placement.copyWith(trigger: const TrapRect(0, 0, 0, 10))],
            chunkWidth: 960,
            chunkHeight: 320,
          ),
          throwsArgumentError,
        );
      }
    }
  });
}
