import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/combat/damage_type.dart';
import 'package:rpg_runner/core/combat/status/status.dart';
import 'package:rpg_runner/core/events/entity_visual_cue_coalescer.dart';
import 'package:rpg_runner/core/events/game_event.dart';

void main() {
  test(
    'coalesces same-tick cues by entity and kind using highest intensity',
    () {
      final coalescer = EntityVisualCueCoalescer();
      coalescer.resetForTick(100);

      coalescer.record(
        tick: 100,
        entityId: 7,
        kind: EntityVisualCueKind.directHit,
        intensityBp: 2000,
        damageType: DamageType.physical,
      );
      coalescer.record(
        tick: 100,
        entityId: 7,
        kind: EntityVisualCueKind.directHit,
        intensityBp: 6500,
        damageType: DamageType.fire,
      );
      coalescer.record(
        tick: 100,
        entityId: 7,
        kind: EntityVisualCueKind.dotPulse,
        intensityBp: 3200,
        damageType: DamageType.bleed,
      );
      coalescer.record(
        tick: 100,
        entityId: 9,
        kind: EntityVisualCueKind.resourcePulse,
        intensityBp: 2800,
        resourceType: StatusResourceType.mana,
      );

      final emitted = <EntityVisualCueEvent>[];
      coalescer.emit(emitted.add);

      expect(emitted.length, equals(3));
      final byKey = <String, EntityVisualCueEvent>{
        for (final event in emitted)
          '${event.entityId}:${event.kind.name}': event,
      };

      final directHit = byKey['7:directHit'];
      expect(directHit, isNotNull);
      expect(directHit!.tick, equals(100));
      expect(directHit.intensityBp, equals(6500));
      expect(directHit.damageType, equals(DamageType.fire));

      final dotPulse = byKey['7:dotPulse'];
      expect(dotPulse, isNotNull);
      expect(dotPulse!.intensityBp, equals(3200));
      expect(dotPulse.damageType, equals(DamageType.bleed));

      final resourcePulse = byKey['9:resourcePulse'];
      expect(resourcePulse, isNotNull);
      expect(resourcePulse!.intensityBp, equals(2800));
      expect(resourcePulse.resourceType, equals(StatusResourceType.mana));
    },
  );

  test('ignores wrong tick and non-positive intensities', () {
    final coalescer = EntityVisualCueCoalescer();
    coalescer.resetForTick(25);

    coalescer.record(
      tick: 24,
      entityId: 1,
      kind: EntityVisualCueKind.directHit,
      intensityBp: 5000,
      damageType: DamageType.fire,
    );
    coalescer.record(
      tick: 25,
      entityId: 1,
      kind: EntityVisualCueKind.directHit,
      intensityBp: 0,
      damageType: DamageType.fire,
    );
    coalescer.record(
      tick: 25,
      entityId: 2,
      kind: EntityVisualCueKind.dotPulse,
      intensityBp: -10,
      damageType: DamageType.bleed,
    );

    final emitted = <EntityVisualCueEvent>[];
    coalescer.emit(emitted.add);
    expect(emitted, isEmpty);
  });

  test('resetForTick clears pending aggregates from previous tick', () {
    final coalescer = EntityVisualCueCoalescer();
    coalescer.resetForTick(5);
    coalescer.record(
      tick: 5,
      entityId: 3,
      kind: EntityVisualCueKind.directHit,
      intensityBp: 4000,
      damageType: DamageType.ice,
    );

    coalescer.resetForTick(6);

    final emitted = <EntityVisualCueEvent>[];
    coalescer.emit(emitted.add);
    expect(emitted, isEmpty);
  });
}
