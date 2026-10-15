import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/controls/control_resource_usage.dart';
import 'package:rpg_runner/ui/hud/game/resource_bar.dart';

void main() {
  Widget host({
    double value = 100,
    double maximum = 100,
    HudResource resource = HudResource.health,
    bool active = true,
    bool reduced = false,
    ValueNotifier<ControlResourceUsage>? warnings,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Center(
        child: ResourceBar(
          resource: resource,
          value: value,
          maximum: maximum,
          active: active,
          warningSignal: warnings,
        ),
      ),
    ),
  );
  double fill(WidgetTester tester) => tester
      .widget<FractionallySizedBox>(find.byKey(const ValueKey('resource-fill')))
      .widthFactor!;
  double trail(WidgetTester tester) => tester
      .widget<FractionallySizedBox>(
        find.byKey(const ValueKey('resource-loss-trail')),
      )
      .widthFactor!;

  testWidgets(
    'damage is immediate, trail holds then drains through regeneration',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpWidget(host(value: 50));
      expect(fill(tester), .5);
      expect(trail(tester), 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(trail(tester), 1);
      await tester.pumpWidget(host(value: 51));
      await tester.pump(const Duration(milliseconds: 220));
      expect(trail(tester), inExclusiveRange(.51, 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('resource-loss-trail')), findsNothing);
      expect(fill(tester), closeTo(.51, .0001));
    },
  );

  testWidgets(
    'successive hits preserve recent loss and restoration never overshoots',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpWidget(host(value: 70));
      await tester.pump(const Duration(milliseconds: 250));
      final before = trail(tester);
      await tester.pumpWidget(host(value: 40));
      expect(fill(tester), .4);
      expect(trail(tester), closeTo(before, .001));
      await tester.pumpWidget(host(value: 100));
      expect(find.byKey(const ValueKey('resource-loss-trail')), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(fill(tester), inExclusiveRange(.4, 1));
      await tester.pumpAndSettle();
      expect(fill(tester), 1);
    },
  );

  for (final resource in [HudResource.mana, HudResource.stamina]) {
    testWidgets(
      '$resource spending snaps and continuous regeneration makes progress',
      (tester) async {
        await tester.pumpWidget(host(resource: resource));
        await tester.pumpWidget(host(resource: resource, value: 40));
        expect(fill(tester), .4);
        for (var value = 41; value <= 60; value++) {
          await tester.pumpWidget(
            host(resource: resource, value: value.toDouble()),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(fill(tester), inExclusiveRange(.55, .6));
        expect(find.byKey(const ValueKey('resource-loss-trail')), findsNothing);
        await tester.pumpAndSettle();
        expect(fill(tester), .6);
      },
    );
  }

  testWidgets(
    'pause and reduced motion settle values and stop low-health pulses',
    (tester) async {
      await tester.pumpWidget(host(value: 20));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(host(value: 20, active: false));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(host(value: 15, reduced: true));
      expect(fill(tester), .15);
      expect(find.byKey(const ValueKey('resource-loss-trail')), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(host(value: 60, reduced: true));
      expect(fill(tester), .6);
    },
  );

  testWidgets(
    'maximum changes reset trails and zero maximum has an empty fill',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpWidget(host(value: 50));
      await tester.pumpWidget(host(value: 50, maximum: 200));
      expect(fill(tester), .25);
      expect(find.byKey(const ValueKey('resource-loss-trail')), findsNothing);
      await tester.pumpWidget(host(value: 50, maximum: 0));
      expect(fill(tester), 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('warnings filter resources, expire and detach when replaced', (
    tester,
  ) async {
    final warnings = ValueNotifier<ControlResourceUsage>(
      ControlResourceUsage.none,
    );
    final replacement = ValueNotifier<ControlResourceUsage>(
      ControlResourceUsage.none,
    );
    addTearDown(warnings.dispose);
    addTearDown(replacement.dispose);
    await tester.pumpWidget(host(warnings: warnings, reduced: true));
    warnings.value = const ControlResourceUsage(mana: true);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    warnings.value = const ControlResourceUsage(health: true);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(host(warnings: replacement));
    warnings.value = ControlResourceUsage(health: true);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    replacement.value = const ControlResourceUsage(health: true);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 1);
    await tester.pumpWidget(const SizedBox());
    replacement.value = ControlResourceUsage(health: true);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resource names and live values remain accessible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(resource: HudResource.mana, value: 45));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Mana')).value,
      '45 / 100',
    );
    expect(tester.getSize(find.byType(ResourceBar)).width, 180);
    semantics.dispose();
  });
}
