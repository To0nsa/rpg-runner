import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/game/input/aim_preview.dart';
import 'package:rpg_runner/ui/controls/cooldown_ring.dart';
import 'package:rpg_runner/ui/controls/controls_tuning.dart';
import 'package:rpg_runner/ui/controls/directional_action_button.dart';
import 'package:rpg_runner/ui/controls/layout/controls_radial_layout.dart';
import 'package:rpg_runner/ui/controls/runner_controls_overlay_radial.dart';
import 'package:rpg_runner/ui/controls/widgets/bonus_control.dart';
import 'package:rpg_runner/ui/controls/widgets/melee_control.dart';

void main() {
  testWidgets('bonus control is anchored above Atk control by tuning offset', (
    tester,
  ) async {
    final harness = _OverlayHarness();
    addTearDown(harness.dispose);

    const tuning = ControlsTuning.fixed;
    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: tuning)),
    );

    final bonus = _positionedFor(tester, find.byType(BonusControl));
    final melee = _positionedFor(tester, find.byType(MeleeControl));

    expect(bonus.right, closeTo(melee.right!, 0.001));
    expect(
      bonus.bottom,
      closeTo(melee.bottom! + tuning.layout.bonusVerticalOffset, 0.001),
    );
  });

  testWidgets('charge bar anchor maps to projectile charge layout', (
    tester,
  ) async {
    final harness = _OverlayHarness();
    addTearDown(harness.dispose);

    const tuning = ControlsTuning.fixed;
    final expected = ControlsRadialLayoutSolver.solve(
      layout: tuning.layout,
      action: tuning.style.actionButton,
      directional: tuning.style.directionalActionButton,
    );

    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: tuning)),
    );

    harness.chargeBarVisible = true;
    harness.chargeBarProgress01 = 0.4;
    harness.chargeBarTier = 1;
    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: tuning)),
    );

    final projectilePos = _chargeBarPositioned(tester);
    expect(
      projectilePos.right,
      closeTo(expected.projectileCharge.right, 0.001),
    );
    expect(
      projectilePos.bottom,
      closeTo(expected.projectileCharge.bottom, 0.001),
    );
  });

  testWidgets('charge bar is hidden when projectile charge is inactive', (
    tester,
  ) async {
    final harness = _OverlayHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
    );

    harness.chargeBarVisible = false;
    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
    );

    expect(_chargeBarFinder(), findsNothing);
  });

  testWidgets(
    'controls propagate cooldown ring tuning to cooldown ring widgets',
    (tester) async {
      final harness = _OverlayHarness();
      addTearDown(harness.dispose);

      const cooldownRing = CooldownRingTuning(
        thickness: 7,
        trackColor: Color(0xFF224466),
        progressColor: Color(0xFF88CCEE),
      );
      const tuning = ControlsTuning(
        style: ControlsStyleTuning(cooldownRing: cooldownRing),
      );

      await tester.pumpWidget(
        _testHost(child: harness.buildOverlay(tuning: tuning)),
      );

      final rings = tester.widgetList<CooldownRing>(find.byType(CooldownRing));
      expect(rings, isNotEmpty);
      for (final ring in rings) {
        expect(ring.tuning.thickness, cooldownRing.thickness);
        expect(ring.tuning.trackColor, cooldownRing.trackColor);
        expect(ring.tuning.progressColor, cooldownRing.progressColor);
      }
    },
  );

  testWidgets('charge bar uses tuned visuals', (tester) async {
    final harness = _OverlayHarness();
    addTearDown(harness.dispose);

    const chargeBar = ChargeBarTuning(
      width: 99,
      height: 16,
      padding: 3,
      backgroundColor: Color(0xFF112233),
      borderColor: Color(0xFF445566),
      borderWidth: 2,
      outerRadius: 9,
      innerRadius: 4,
      idleColor: Color(0xFF778899),
      halfTierColor: Color(0xFFCCAA33),
      fullTierColor: Color(0xFF33CC88),
    );
    const tuning = ControlsTuning(
      style: ControlsStyleTuning(chargeBar: chargeBar),
    );

    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: tuning)),
    );

    harness.chargeBarVisible = true;
    harness.chargeBarProgress01 = 1.0;
    harness.chargeBarTier = 2;
    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: tuning)),
    );

    final chargeBarFinder = _chargeBarFinder();
    expect(chargeBarFinder, findsOneWidget);

    final outerFinder = find.descendant(
      of: chargeBarFinder,
      matching: find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.color == chargeBar.backgroundColor;
      }),
    );
    expect(outerFinder, findsOneWidget);
    expect(
      tester.getSize(outerFinder),
      Size(chargeBar.width, chargeBar.height),
    );

    final outer = tester.widget<Container>(outerFinder);
    expect(outer.padding, EdgeInsets.all(chargeBar.padding));
    final outerDecoration = outer.decoration;
    expect(outerDecoration, isA<BoxDecoration>());
    final outerBox = outerDecoration! as BoxDecoration;
    expect(outerBox.color, chargeBar.backgroundColor);
    expect(outerBox.borderRadius, BorderRadius.circular(chargeBar.outerRadius));
    final border = outerBox.border;
    expect(border, isA<Border>());
    final side = (border! as Border).top;
    expect(side.color, chargeBar.borderColor);
    expect(side.width, chargeBar.borderWidth);

    final fillFinder = find.descendant(
      of: chargeBarFinder,
      matching: find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.color == chargeBar.fullTierColor;
      }),
    );
    expect(fillFinder, findsOneWidget);

    final fill = tester.widget<Container>(fillFinder);
    final fillDecoration = fill.decoration;
    expect(fillDecoration, isA<BoxDecoration>());
    final fillBox = fillDecoration! as BoxDecoration;
    expect(fillBox.borderRadius, BorderRadius.circular(chargeBar.innerRadius));
  });

  testWidgets(
    'secondary hold-aim-release renders directional secondary control',
    (tester) async {
      final harness = _OverlayHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(
        _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
      );

      harness.secondaryInputMode = AbilityInputMode.holdAimRelease;
      await tester.pumpWidget(
        _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
      );

      // Projectile + melee directional controls are always present in this harness;
      // hold-aim-release secondary adds a third one.
      expect(find.byType(DirectionalActionButton), findsNWidgets(3));
    },
  );

  testWidgets(
    'secondary hold-release renders non-directional secondary control',
    (tester) async {
      final harness = _OverlayHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(
        _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
      );

      harness.secondaryInputMode = AbilityInputMode.holdRelease;
      await tester.pumpWidget(
        _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
      );

      // Projectile + melee directional controls remain; secondary is hold-release.
      expect(find.byType(DirectionalActionButton), findsNWidgets(2));
    },
  );

  testWidgets('mobility hold-aim-release renders directional mobility control', (
    tester,
  ) async {
    final harness = _OverlayHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
    );

    harness.mobilityInputMode = AbilityInputMode.holdAimRelease;
    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
    );

    // Projectile + melee directional controls are always present in this harness;
    // hold-aim-release mobility adds a third one.
    expect(find.byType(DirectionalActionButton), findsNWidgets(3));
  });

  testWidgets('mobility hold-release renders non-directional mobility control', (
    tester,
  ) async {
    final harness = _OverlayHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
    );

    harness.mobilityInputMode = AbilityInputMode.holdRelease;
    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
    );

    // Projectile + melee directional controls remain; mobility is hold-release.
    expect(find.byType(DirectionalActionButton), findsNWidgets(2));
  });
}

Widget _testHost({required Widget child}) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(width: 480, height: 320, child: child)),
  );
}

Positioned _positionedFor(WidgetTester tester, Finder childFinder) {
  final positionedFinder = find.ancestor(
    of: childFinder,
    matching: find.byType(Positioned),
  );
  expect(positionedFinder, findsOneWidget);
  return tester.widget<Positioned>(positionedFinder);
}

Finder _chargeBarFinder() {
  return find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_ChargeBar',
  );
}

Positioned _chargeBarPositioned(WidgetTester tester) {
  final chargeBar = _chargeBarFinder();
  expect(chargeBar, findsOneWidget);
  return _positionedFor(tester, chargeBar);
}

class _OverlayHarness {
  final AimPreviewModel projectileAimPreview = AimPreviewModel();
  final AimPreviewModel meleeAimPreview = AimPreviewModel();
  final ValueNotifier<Rect?> cancelHitboxRect = ValueNotifier<Rect?>(null);
  final ValueNotifier<int> forceCancelSignal = ValueNotifier<int>(0);
  bool chargeBarVisible = false;
  double chargeBarProgress01 = 0.0;
  int chargeBarTier = 0;
  AbilityInputMode secondaryInputMode = AbilityInputMode.tap;
  AbilityInputMode mobilityInputMode = AbilityInputMode.tap;

  RunnerControlsOverlay buildOverlay({required ControlsTuning tuning}) {
    return RunnerControlsOverlay(
      tuning: tuning,
      onMoveAxis: (_) {},
      onJumpPressed: () {},
      onMobilityPressed: () {},
      onMobilityCommitted: () {},
      onMobilityHoldStart: () {},
      onMobilityHoldEnd: () {},
      onSecondaryPressed: () {},
      onSecondaryCommitted: () {},
      onSecondaryHoldStart: () {},
      onSecondaryHoldEnd: () {},
      onBonusPressed: () {},
      onProjectileCommitted: () {},
      onProjectilePressed: () {},
      onProjectileHoldStart: () {},
      onProjectileHoldEnd: () {},
      onAimDir: (_, _) {},
      onAimClear: () {},
      projectileAimPreview: projectileAimPreview,
      projectileAffordable: true,
      projectileCooldownTicksLeft: 0,
      projectileCooldownTicksTotal: 0,
      onMeleeCommitted: () {},
      onMeleePressed: () {},
      onMeleeHoldStart: () {},
      onMeleeHoldEnd: () {},
      onMeleeChargeHoldStart: () {},
      onMeleeChargeHoldEnd: () {},
      meleeAimPreview: meleeAimPreview,
      aimCancelHitboxRect: cancelHitboxRect,
      meleeAffordable: true,
      meleeCooldownTicksLeft: 0,
      meleeCooldownTicksTotal: 0,
      meleeInputMode: AbilityInputMode.holdAimRelease,
      secondaryInputMode: secondaryInputMode,
      projectileInputMode: AbilityInputMode.holdAimRelease,
      mobilityInputMode: mobilityInputMode,
      chargeBarVisible: chargeBarVisible,
      chargeBarProgress01: chargeBarProgress01,
      chargeBarTier: chargeBarTier,
      jumpAffordable: true,
      mobilityAffordable: true,
      mobilityCooldownTicksLeft: 0,
      mobilityCooldownTicksTotal: 0,
      secondaryAffordable: true,
      secondaryCooldownTicksLeft: 0,
      secondaryCooldownTicksTotal: 0,
      bonusAffordable: true,
      bonusCooldownTicksLeft: 0,
      bonusCooldownTicksTotal: 0,
      forceAimCancelSignal: forceCancelSignal,
    );
  }

  void dispose() {
    projectileAimPreview.dispose();
    meleeAimPreview.dispose();
    cancelHitboxRect.dispose();
    forceCancelSignal.dispose();
  }
}
