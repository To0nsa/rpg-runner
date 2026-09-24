import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_geometry.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';
import 'package:runner_core/traps/trap_validation.dart';
import 'package:test/test.dart';

void main() {
  test('reviewed art sequences retain cumulative duration and warning', () {
    for (final (id, count, milliseconds, warningMs, sheetWidth, sheetHeight)
        in [
          (TrapId.spike, 27, 2520, 700, 1920, 256),
          (TrapId.swingingAxe, 51, 9380, 800, 2816, 512),
          (TrapId.poisonDarts, 14, 1600, 500, 1536, 1152),
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

  test(
    'placement tuning retimes wind-up and preserves attack/recovery poses',
    () {
      for (final id in TrapId.values) {
        final def = TrapCatalog.get(id);
        for (final hz in [30, 60, 120]) {
          for (final windup in [0, 125, 1000, 30000]) {
            final first = (windup * hz + 999) ~/ 1000;
            expect(def.firstHarmfulTick(hz, windupMs: windup), first);
            if (first > 0) {
              expect(
                def.frameAtTick(first - 1, hz, windupMs: windup),
                lessThan(def.firstHarmfulFrame),
              );
            }
            expect(
              def.frameAtTick(first, hz, windupMs: windup),
              def.firstHarmfulFrame,
            );
            var elapsedMs = 0;
            for (var i = 0; i < def.frames.length; i++) {
              if (i >= def.firstHarmfulFrame) {
                expect(
                  def.frameStartTick(i, hz, windupMs: windup),
                  ((windup + elapsedMs - def.windupMs) * hz + 999) ~/ 1000,
                );
              }
              elapsedMs += def.frames[i].durationMs;
            }
            expect(
              def.durationTicks(hz, windupMs: windup),
              ((windup + def.durationMs - def.windupMs) * hz + 999) ~/ 1000,
            );
          }
        }
      }
    },
  );

  test('default tuning is canonical and overrides participate in identity', () {
    const base = TrapPlacement(
      trapId: TrapId.spike,
      x: 300,
      y: 160,
      trigger: TrapRect(-40, -20, 80, 40),
    );
    final explicit = base.copyWith(damage100: 500, windupMs: 700);
    expect(explicit, base);
    expect(explicit.hashCode, base.hashCode);
    expect(explicit.toJson(), base.toJson());
    expect(base.zIndex, -21);
    final raised = base.copyWith(zIndex: 7);
    expect(raised, isNot(base));
    expect(raised.copyWith(x: 320).zIndex, 7);
    expect(raised.toJson()['zIndex'], 7);
    expect(raised.copyWith(zIndex: -21).toJson(), base.toJson());
    final changed = base.copyWith(damage100: 125, windupMs: 125);
    expect(changed, isNot(base));
    expect(changed.copyWith(x: 320).damage100, 125);
    expect(changed.toJson()['windupMs'], 125);
    for (final candidate in [
      base.copyWith(damage100: 0),
      base.copyWith(damage100: TrapPlacement.maxDamage100 + 1),
      base.copyWith(windupMs: -1),
      base.copyWith(windupMs: TrapPlacement.maxWindupMs + 1),
    ]) {
      expect(
        () => validateTrapPlacements(
          [candidate],
          chunkWidth: 960,
          chunkHeight: 320,
        ),
        throwsArgumentError,
      );
    }
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
