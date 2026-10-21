import 'package:rpg_runner/ui/controls/control_resource_usage.dart';
import 'package:rpg_runner/ui/controls/ability_slot_visual_spec.dart';
import 'package:rpg_runner/ui/controls/control_button_visuals.dart';
import 'package:rpg_runner/ui/components/gameIcon/game_icon.dart';
import 'package:rpg_runner/ui/theme/ui_action_button_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:rpg_runner/game/input/aim_preview.dart';
import 'package:rpg_runner/ui/controls/cooldown_ring.dart';
import 'package:rpg_runner/ui/controls/controls_tuning.dart';
import 'package:rpg_runner/ui/controls/directional_action_button.dart';
import 'package:rpg_runner/ui/controls/layout/controls_radial_layout.dart';
import 'package:rpg_runner/ui/controls/runner_controls_overlay_radial.dart';
import 'package:rpg_runner/ui/controls/widgets/spell_control.dart';
import 'package:rpg_runner/ui/controls/move_joystick.dart';
import 'package:rpg_runner/ui/controls/move_buttons.dart';
import 'package:rpg_runner/ui/controls/movement_control_mode.dart';
import 'package:rpg_runner/ui/controls/action_button.dart';

void main() {
  testWidgets('mobility follow-up is visible and usable during cooldown', (
    tester,
  ) async {
    final harness = _OverlayHarness()
      ..mobilityCooldownTicksLeft = 112
      ..mobilityRecastAvailable = true;
    addTearDown(harness.dispose);
    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
    );
    expect(find.text('+1'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Mobility, follow-up available'));
    expect(harness.gameplayEdges, ['mobility.press']);
    harness.mobilityRecastAvailable = false;
    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
    );
    expect(find.text('+1'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Mobility'));
    expect(harness.gameplayEdges, ['mobility.press']);
  });

  testWidgets('mobility follow-up still requires its resource cost', (
    tester,
  ) async {
    final harness = _OverlayHarness()
      ..mobilityCooldownTicksLeft = 112
      ..mobilityRecastAvailable = true
      ..mobilityAffordable = false
      ..missingResources = {
        AbilitySlot.mobility: const ControlResourceUsage(stamina: true),
      };
    addTearDown(harness.dispose);
    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
    );
    await tester.tap(find.bySemanticsLabel('Mobility, follow-up available'));
    expect(harness.gameplayEdges, isEmpty);
    expect(harness.shortfalls, hasLength(1));
    await tester.pumpAndSettle();
  });

  for (final mode in AbilityInputMode.values) {
    testWidgets(
      'resource-blocked $mode warns on every tap without gameplay edges',
      (tester) async {
        final harness = _OverlayHarness()
          ..meleeInputMode = mode
          ..meleeAffordable = false
          ..missingResources = {
            AbilitySlot.primary: const ControlResourceUsage(stamina: true),
          };
        addTearDown(harness.dispose);
        await tester.pumpWidget(
          _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
        );
        await tester.tapAt(tester.getCenter(find.bySemanticsLabel('Sword')));
        await tester.pump();
        await tester.tapAt(tester.getCenter(find.bySemanticsLabel('Sword')));
        await tester.pump();
        expect(harness.shortfalls, hasLength(2));
        expect(harness.shortfalls.every((missing) => missing.stamina), isTrue);
        expect(harness.gameplayEdges, isEmpty);
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('cooldown does not warn even if resources are also missing', (
    tester,
  ) async {
    final harness = _OverlayHarness()
      ..projectileCooldownTicksLeft = 10
      ..missingResources = {
        AbilitySlot.projectile: const ControlResourceUsage(mana: true),
      };
    addTearDown(harness.dispose);
    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
    );
    await tester.tap(find.bySemanticsLabel('Projectile'), warnIfMissed: false);
    expect(harness.shortfalls, isEmpty);
    expect(harness.gameplayEdges, isEmpty);
  });
  testWidgets('all six controls show symbols and resource tints without text', (
    tester,
  ) async {
    final harness = _OverlayHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
    );
    expect(find.byType(Text), findsNothing);
    expect(find.byType(GameIcon), findsNothing);
    for (final slot in abilityRadialLayoutSpec.slots) {
      expect(find.byIcon(slot.icon), findsOneWidget);
      expect(find.bySemanticsLabel(slot.label), findsOneWidget);
    }
    final mana = tester.widget<ControlButtonSurface>(
      find.descendant(
        of: find.bySemanticsLabel('Projectile'),
        matching: find.byType(ControlButtonSurface),
      ),
    );
    final stamina = tester.widget<ControlButtonSurface>(
      find.descendant(
        of: find.bySemanticsLabel('Sword'),
        matching: find.byType(ControlButtonSurface),
      ),
    );
    final theme = UiActionButtonTheme.standard;
    expect(
      mana.visual.backgroundColor,
      theme
          .resourceBackgrounds(const ControlResourceUsage(mana: true))
          .single
          .withValues(alpha: theme.run.backgroundColor.a),
    );
    expect(
      stamina.visual.backgroundColor,
      theme
          .resourceBackgrounds(const ControlResourceUsage(stamina: true))
          .single
          .withValues(alpha: theme.run.backgroundColor.a),
    );
  });

  testWidgets(
    'floating movement captures the lower-left area and leaves actions usable',
    (tester) async {
      final harness = _OverlayHarness()
        ..movementMode = MovementControlMode.joystick;
      addTearDown(harness.dispose);
      Future<void> pumpOverlay() => tester.pumpWidget(
        _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
      );
      await pumpOverlay();
      expect(
        tester.getRect(find.byType(MoveJoystick)),
        const Rect.fromLTWH(0, 160, 158.4, 160),
      );
      final finger = await tester.startGesture(
        const Offset(60, 220),
        pointer: 1,
      );
      await finger.moveTo(const Offset(400, 220));
      await tester.pump();
      expect(harness.movementAxes.last, 1);
      expect(
        tester
            .getCenter(find.byKey(const ValueKey('movement_joystick_base')))
            .dx,
        closeTo(480 * 0.33, 0.001),
      );
      await tester.tap(
        find.ancestor(
          of: find.bySemanticsLabel('Jump'),
          matching: find.byType(ActionButton),
        ),
        pointer: 2,
      );
      expect(harness.gameplayEdges, contains('jump.press'));
      expect(harness.movementAxes.last, 1);
      harness.movementMode = MovementControlMode.arrows;
      await pumpOverlay();
      expect(harness.movementAxes.last, 0);
      expect(
        tester.getRect(find.byType(MoveButtons)),
        const Rect.fromLTWH(32, 256, 136, 48),
      );
      await finger.up();
      final arrow = await tester.startGesture(
        tester.getRect(find.byType(MoveButtons)).centerRight -
            const Offset(8, 0),
      );
      expect(harness.movementAxes.last, 1);
      harness.movementMode = MovementControlMode.joystick;
      await pumpOverlay();
      expect(harness.movementAxes.last, 0);
      await arrow.up();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'floating center stays in the left 33% across overdrag and resize',
    (tester) async {
      final harness = _OverlayHarness()
        ..movementMode = MovementControlMode.joystick;
      addTearDown(harness.dispose);
      Future<void> pumpWidth(double width) => tester.pumpWidget(
        _testHost(
          width: width,
          child: harness.buildOverlay(tuning: ControlsTuning.fixed),
        ),
      );
      await pumpWidth(800);
      final base = find.byKey(const ValueKey('movement_joystick_base'));
      const start = Offset(800 * 0.33 - 1, 220);
      final finger = await tester.startGesture(start);
      await tester.pump();
      expect(tester.getCenter(base), start);
      expect(harness.movementAxes, isEmpty);
      await finger.moveTo(const Offset(760, 220));
      await tester.pump();
      expect(tester.getCenter(base).dx, closeTo(800 * 0.33, 0.001));
      expect(harness.movementAxes.last, 1);
      await pumpWidth(480);
      expect(tester.getCenter(base).dx, closeTo(480 * 0.33, 0.001));
      await finger.moveTo(const Offset(480 * 0.33, 220));
      expect(harness.movementAxes.last, 0);
      await finger.moveBy(const Offset(-9, 0));
      expect(harness.movementAxes.last, -1);
      await finger.cancel();
      await tester.pump();
      expect(harness.movementAxes.last, 0);
      expect(tester.getCenter(base), const Offset(80, 256));
    },
  );

  testWidgets(
    'fixed joystick uses the lower-left anchor and leaves actions usable',
    (tester) async {
      final harness = _OverlayHarness()
        ..movementMode = MovementControlMode.fixedJoystick;
      addTearDown(harness.dispose);
      await tester.pumpWidget(
        _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
      );
      expect(
        tester.getRect(find.byType(MoveJoystick)),
        const Rect.fromLTWH(32, 208, 96, 96),
      );
      await tester.tapAt(const Offset(160, 190));
      expect(harness.movementAxes, isEmpty);
      final finger = await tester.startGesture(
        const Offset(100, 256),
        pointer: 1,
      );
      expect(harness.movementAxes.last, 1);
      await tester.tap(find.bySemanticsLabel('Jump'), pointer: 2);
      expect(harness.gameplayEdges, contains('jump.press'));
      expect(harness.movementAxes.last, 1);
      await finger.up();
      expect(harness.movementAxes.last, 0);
    },
  );

  testWidgets(
    'spell control is anchored above Shield control by tuning offset',
    (tester) async {
      final harness = _OverlayHarness();
      addTearDown(harness.dispose);

      const tuning = ControlsTuning.fixed;
      await tester.pumpWidget(
        _testHost(child: harness.buildOverlay(tuning: tuning)),
      );

      final bonus = _positionedFor(tester, find.byType(SpellControl));
      final shield = _positionedFor(tester, find.bySemanticsLabel('Shield'));

      expect(bonus.right, closeTo(shield.right!, 0.001));
      expect(
        bonus.bottom,
        closeTo(shield.bottom! + tuning.layout.spellVerticalOffset, 0.001),
      );
    },
  );

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

  testWidgets(
    'mobility hold-aim-release renders directional mobility control',
    (tester) async {
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
    },
  );

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

  testWidgets('projectile control is hidden when projectile slot is absent', (
    tester,
  ) async {
    final harness = _OverlayHarness();
    addTearDown(harness.dispose);

    harness.hasProjectileSlot = false;
    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
    );

    expect(find.bySemanticsLabel('Projectile'), findsNothing);
    // Baseline directional controls are projectile + melee.
    expect(find.byType(DirectionalActionButton), findsOneWidget);
  });

  testWidgets('secondary control is hidden when secondary slot is absent', (
    tester,
  ) async {
    final harness = _OverlayHarness();
    addTearDown(harness.dispose);

    harness.hasSecondarySlot = false;
    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
    );

    expect(find.bySemanticsLabel('Shield'), findsNothing);
  });

  testWidgets('production slot modes emit the expected callback edges', (
    tester,
  ) async {
    final harness = _OverlayHarness();
    addTearDown(harness.dispose);

    Future<void> pumpOverlay() => tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
    );

    Future<void> pressAndRelease(String label) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.bySemanticsLabel(label)),
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();
    }

    harness.meleeInputMode = AbilityInputMode.tap;
    harness.projectileInputMode = AbilityInputMode.tap;
    harness.secondaryInputMode = AbilityInputMode.holdMaintain;
    harness.mobilityInputMode = AbilityInputMode.tap;
    await pumpOverlay();

    await pressAndRelease('Sword');
    await pressAndRelease('Projectile');
    await pressAndRelease('Shield');
    await pressAndRelease('Mobility');
    await pressAndRelease('Spell');
    await pressAndRelease('Jump');

    expect(harness.gameplayEdges, <String>[
      'primary.press',
      'projectile.press',
      'secondary.hold.start',
      'secondary.hold.end',
      'mobility.press',
      'spell.press',
      'jump.press',
    ]);

    harness.gameplayEdges.clear();
    harness.meleeInputMode = AbilityInputMode.holdAimRelease;
    harness.projectileInputMode = AbilityInputMode.holdAimRelease;
    await pumpOverlay();

    await pressAndRelease('Sword');
    await pressAndRelease('Projectile');

    expect(
      harness.gameplayEdges.where((edge) => !edge.startsWith('aim.')),
      <String>[
        'primary.charge.start',
        'primary.commit',
        'primary.charge.end',
        'projectile.hold.start',
        'projectile.commit',
        'projectile.hold.end',
      ],
    );
  });

  testWidgets('blocked tap controls emit no gameplay callbacks', (
    tester,
  ) async {
    final harness = _OverlayHarness()
      ..meleeInputMode = AbilityInputMode.tap
      ..projectileInputMode = AbilityInputMode.tap
      ..meleeAffordable = false
      ..projectileCooldownTicksLeft = 1;
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      _testHost(child: harness.buildOverlay(tuning: ControlsTuning.fixed)),
    );

    await tester.tap(find.bySemanticsLabel('Sword'), warnIfMissed: false);
    await tester.tap(find.bySemanticsLabel('Projectile'), warnIfMissed: false);
    await tester.pump();

    expect(harness.gameplayEdges, isEmpty);
  });
}

Widget _testHost({required Widget child, double width = 480}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(width: width, height: 320, child: child),
    ),
  );
}

Positioned _positionedFor(WidgetTester tester, Finder childFinder) {
  final positionedFinder = find.ancestor(
    of: childFinder,
    matching: find.byWidgetPredicate((widget) {
      if (widget is! Positioned) return false;
      return widget.left == null &&
          widget.top == null &&
          widget.right != null &&
          widget.bottom != null;
    }),
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
  int mobilityCooldownTicksLeft = 0;
  bool mobilityRecastAvailable = false;
  bool mobilityAffordable = true;
  Map<AbilitySlot, ControlResourceUsage> missingResources = {};
  final List<ControlResourceUsage> shortfalls = [];
  final AimPreviewModel projectileAimPreview = AimPreviewModel();
  final AimPreviewModel meleeAimPreview = AimPreviewModel();
  final ValueNotifier<Rect?> cancelHitboxRect = ValueNotifier<Rect?>(null);
  final ValueNotifier<int> forceCancelSignal = ValueNotifier<int>(0);
  bool chargeBarVisible = false;
  double chargeBarProgress01 = 0.0;
  int chargeBarTier = 0;
  AbilityInputMode secondaryInputMode = AbilityInputMode.tap;
  AbilityInputMode mobilityInputMode = AbilityInputMode.tap;
  AbilityInputMode meleeInputMode = AbilityInputMode.holdAimRelease;
  AbilityInputMode projectileInputMode = AbilityInputMode.holdAimRelease;
  bool hasSecondarySlot = true;
  bool hasProjectileSlot = true;
  bool meleeAffordable = true;
  int projectileCooldownTicksLeft = 0;
  final List<String> gameplayEdges = <String>[];
  MovementControlMode movementMode = MovementControlMode.arrows;
  final List<double> movementAxes = <double>[];

  RunnerControlsOverlay buildOverlay({required ControlsTuning tuning}) {
    return RunnerControlsOverlay(
      missingResourcesBySlot: missingResources,
      onResourceShortfall: shortfalls.add,
      tuning: tuning,
      movementControlMode: movementMode,
      onMoveAxis: movementAxes.add,
      onJumpPressed: () => gameplayEdges.add('jump.press'),
      onMobilityPressed: () => gameplayEdges.add('mobility.press'),
      onMobilityCommitted: () => gameplayEdges.add('mobility.commit'),
      onMobilityHoldStart: () => gameplayEdges.add('mobility.hold.start'),
      onMobilityHoldEnd: () => gameplayEdges.add('mobility.hold.end'),
      onSecondaryPressed: () => gameplayEdges.add('secondary.press'),
      onSecondaryCommitted: () => gameplayEdges.add('secondary.commit'),
      onSecondaryHoldStart: () => gameplayEdges.add('secondary.hold.start'),
      onSecondaryHoldEnd: () => gameplayEdges.add('secondary.hold.end'),
      onSpellPressed: () => gameplayEdges.add('spell.press'),
      onProjectileCommitted: () => gameplayEdges.add('projectile.commit'),
      onProjectilePressed: () => gameplayEdges.add('projectile.press'),
      onProjectileHoldStart: () => gameplayEdges.add('projectile.hold.start'),
      onProjectileHoldEnd: () => gameplayEdges.add('projectile.hold.end'),
      onAimDir: (_, _) => gameplayEdges.add('aim.update'),
      onAimClear: () => gameplayEdges.add('aim.clear'),
      projectileAimPreview: projectileAimPreview,
      projectileAffordable: true,
      projectileCooldownTicksLeft: projectileCooldownTicksLeft,
      projectileCooldownTicksTotal: 0,
      onMeleeCommitted: () => gameplayEdges.add('primary.commit'),
      onMeleePressed: () => gameplayEdges.add('primary.press'),
      onMeleeHoldStart: () => gameplayEdges.add('primary.hold.start'),
      onMeleeHoldEnd: () => gameplayEdges.add('primary.hold.end'),
      onMeleeChargeHoldStart: () => gameplayEdges.add('primary.charge.start'),
      onMeleeChargeHoldEnd: () => gameplayEdges.add('primary.charge.end'),
      meleeAimPreview: meleeAimPreview,
      aimCancelHitboxRect: cancelHitboxRect,
      meleeAffordable: meleeAffordable,
      meleeCooldownTicksLeft: 0,
      meleeCooldownTicksTotal: 0,
      meleeInputMode: meleeInputMode,
      secondaryInputMode: secondaryInputMode,
      projectileInputMode: projectileInputMode,
      mobilityInputMode: mobilityInputMode,
      chargeBarVisible: chargeBarVisible,
      chargeBarProgress01: chargeBarProgress01,
      chargeBarTier: chargeBarTier,
      jumpAffordable: true,
      mobilityAffordable: mobilityAffordable,
      mobilityRecastAvailable: mobilityRecastAvailable,
      mobilityCooldownTicksLeft: mobilityCooldownTicksLeft,
      mobilityCooldownTicksTotal: 120,
      secondaryAffordable: true,
      secondaryCooldownTicksLeft: 0,
      secondaryCooldownTicksTotal: 0,
      spellAffordable: true,
      spellCooldownTicksLeft: 0,
      spellCooldownTicksTotal: 0,
      forceAimCancelSignal: forceCancelSignal,
      hasSecondarySlot: hasSecondarySlot,
      hasProjectileSlot: hasProjectileSlot,
      resourcesBySlot: const <AbilitySlot, ControlResourceUsage>{
        AbilitySlot.primary: ControlResourceUsage(stamina: true),
        AbilitySlot.secondary: ControlResourceUsage(stamina: true),
        AbilitySlot.projectile: ControlResourceUsage(mana: true),
        AbilitySlot.mobility: ControlResourceUsage(stamina: true),
        AbilitySlot.spell: ControlResourceUsage(mana: true),
        AbilitySlot.jump: ControlResourceUsage(stamina: true),
      },
    );
  }

  void dispose() {
    projectileAimPreview.dispose();
    meleeAimPreview.dispose();
    cancelHitboxRect.dispose();
    forceCancelSignal.dispose();
  }
}
