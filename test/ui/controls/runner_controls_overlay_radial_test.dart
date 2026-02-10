import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/game/input/aim_preview.dart';
import 'package:rpg_runner/game/input/charge_preview.dart';
import 'package:rpg_runner/ui/controls/controls_tuning.dart';
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
      _testHost(
        child: harness.buildOverlay(
          tuning: tuning,
          bonusInputMode: AbilityInputMode.holdAimRelease,
        ),
      ),
    );

    final bonus = _positionedFor(tester, find.byType(BonusControl));
    final melee = _positionedFor(tester, find.byType(MeleeControl));

    expect(bonus.right, closeTo(melee.right!, 0.001));
    expect(
      bonus.bottom,
      closeTo(melee.bottom! + tuning.layout.bonusVerticalOffset, 0.001),
    );
  });

  testWidgets('charge bar anchor maps to projectile and bonus owners', (
    tester,
  ) async {
    final harness = _OverlayHarness();
    addTearDown(harness.dispose);

    const tuning = ControlsTuning.fixed;
    const bonusInputMode = AbilityInputMode.holdAimRelease;
    final expected = ControlsRadialLayoutSolver.solve(
      layout: tuning.layout,
      action: tuning.style.actionButton,
      directional: tuning.style.directionalActionButton,
      bonusMode: BonusAnchorMode.directional,
    );

    await tester.pumpWidget(
      _testHost(
        child: harness.buildOverlay(
          tuning: tuning,
          bonusInputMode: bonusInputMode,
        ),
      ),
    );

    harness.chargePreview.begin(
      ownerId: 'projectile',
      halfTierTicks: 10,
      fullTierTicks: 20,
    );
    harness.chargePreview.updateChargeTicks(8);
    await tester.pump();

    final projectilePos = _chargeBarPositioned(tester);
    expect(
      projectilePos.right,
      closeTo(expected.projectileCharge.right, 0.001),
    );
    expect(
      projectilePos.bottom,
      closeTo(expected.projectileCharge.bottom, 0.001),
    );

    harness.chargePreview.begin(
      ownerId: 'bonus',
      halfTierTicks: 10,
      fullTierTicks: 20,
    );
    harness.chargePreview.updateChargeTicks(8);
    await tester.pump();

    final bonusPos = _chargeBarPositioned(tester);
    expect(bonusPos.right, closeTo(expected.bonusCharge.right, 0.001));
    expect(bonusPos.bottom, closeTo(expected.bonusCharge.bottom, 0.001));
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

Positioned _chargeBarPositioned(WidgetTester tester) {
  final chargeBar = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_ChargeBar',
  );
  expect(chargeBar, findsOneWidget);
  return _positionedFor(tester, chargeBar);
}

class _OverlayHarness {
  final AimPreviewModel projectileAimPreview = AimPreviewModel();
  final AimPreviewModel meleeAimPreview = AimPreviewModel();
  final ChargePreviewModel chargePreview = ChargePreviewModel();
  final ValueNotifier<Rect?> cancelHitboxRect = ValueNotifier<Rect?>(null);
  final ValueNotifier<int> forceCancelSignal = ValueNotifier<int>(0);

  RunnerControlsOverlay buildOverlay({
    required ControlsTuning tuning,
    required AbilityInputMode bonusInputMode,
  }) {
    return RunnerControlsOverlay(
      tuning: tuning,
      onMoveAxis: (_) {},
      onJumpPressed: () {},
      onDashPressed: () {},
      onSecondaryPressed: () {},
      onBonusPressed: () {},
      onBonusCommitted: (_) {},
      onProjectileCommitted: (_) {},
      onProjectilePressed: () {},
      onProjectileAimDir: (_, _) {},
      onProjectileAimClear: () {},
      projectileAimPreview: projectileAimPreview,
      projectileAffordable: true,
      projectileCooldownTicksLeft: 0,
      projectileCooldownTicksTotal: 0,
      onMeleeAimDir: (_, _) {},
      onMeleeAimClear: () {},
      onMeleeCommitted: () {},
      onMeleePressed: () {},
      meleeAimPreview: meleeAimPreview,
      aimCancelHitboxRect: cancelHitboxRect,
      meleeAffordable: true,
      meleeCooldownTicksLeft: 0,
      meleeCooldownTicksTotal: 0,
      meleeInputMode: AbilityInputMode.holdAimRelease,
      projectileInputMode: AbilityInputMode.holdAimRelease,
      bonusInputMode: bonusInputMode,
      bonusUsesMeleeAim: false,
      projectileChargePreview: chargePreview,
      projectileChargeEnabled: true,
      projectileChargeHalfTicks: 10,
      projectileChargeFullTicks: 20,
      bonusChargeEnabled: true,
      bonusChargeHalfTicks: 10,
      bonusChargeFullTicks: 20,
      simulationTickHz: 60,
      jumpAffordable: true,
      dashAffordable: true,
      dashCooldownTicksLeft: 0,
      dashCooldownTicksTotal: 0,
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
    chargePreview.dispose();
    cancelHitboxRect.dispose();
    forceCancelSignal.dispose();
  }
}
