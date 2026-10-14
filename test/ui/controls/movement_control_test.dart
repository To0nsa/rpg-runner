import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/controls/controls_tuning.dart';
import 'package:rpg_runner/ui/controls/move_buttons.dart';
import 'package:rpg_runner/ui/controls/move_joystick.dart';
import 'package:rpg_runner/ui/controls/movement_control_mode.dart';
import 'package:rpg_runner/ui/controls/widgets/movement_control.dart';

void main() {
  Widget host(
    ValueChanged<double> onAxis,
    MovementControlMode mode, {
    bool enabled = true,
    VoidCallback? onAction,
  }) => MaterialApp(
    home: Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 240,
            height: 200,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: MovementControl(
                tuning: ControlsTuning.fixed,
                onMoveAxis: onAxis,
                mode: mode,
                enabled: enabled,
              ),
            ),
          ),
          TextButton(onPressed: onAction, child: const Text('Action')),
        ],
      ),
    ),
  );

  testWidgets(
    'joystick emits full digital axes with neutral center and ignores Y',
    (tester) async {
      final axes = <double>[];
      await tester.pumpWidget(host(axes.add, MovementControlMode.joystick));
      expect(find.byType(MoveButtons), findsNothing);
      final center = tester.getCenter(find.byType(MoveJoystick));
      final finger = await tester.startGesture(center);
      await finger.moveTo(center + const Offset(0, 100));
      expect(axes, isEmpty);
      await finger.moveTo(center + const Offset(9, 0));
      await finger.moveTo(center);
      await finger.moveTo(center - const Offset(9, 0));
      await finger.moveTo(center - const Offset(100, 100));
      await finger.up();
      expect(axes, [1.0, 0.0, -1.0, 0.0]);
    },
  );

  testWidgets(
    'joystick spawns at touch and follows overdrag without moving its hit area',
    (tester) async {
      final axes = <double>[];
      await tester.pumpWidget(host(axes.add, MovementControlMode.joystick));
      final area = tester.getRect(find.byType(MoveJoystick));
      final base = find.byKey(const ValueKey('movement_joystick_base'));
      final thumb = find.byKey(const ValueKey('movement_joystick_thumb'));
      final restingCenter = tester.getCenter(base);
      final start = area.topLeft + const Offset(110, 65);
      final finger = await tester.startGesture(start);
      await tester.pump();
      expect(tester.getCenter(base), start);
      expect(tester.getCenter(thumb), start);
      expect(axes, isEmpty);
      final far = start + const Offset(180, 60);
      await finger.moveTo(far);
      await tester.pump();
      expect(tester.getRect(find.byType(MoveJoystick)), area);
      expect(tester.getCenter(base), far - const Offset(28, 0));
      expect(tester.getCenter(thumb), far);
      expect(axes, [1.0]);
      // Reversal is relative to the following base, not the original touch.
      await finger.moveTo(far - const Offset(28, 0));
      await finger.moveTo(far - const Offset(38, 0));
      expect(axes, [1.0, 0.0, -1.0]);
      await finger.up();
      await tester.pump();
      expect(axes.last, 0);
      expect(tester.getCenter(base), restingCenter);
      final nextStart = area.topLeft + const Offset(65, 120);
      final next = await tester.startGesture(nextStart);
      await tester.pump();
      expect(tester.getCenter(base), nextStart);
      await next.cancel();
      await tester.pump();
      expect(tester.getCenter(base), restingCenter);
    },
  );

  testWidgets(
    'joystick retains its pointer while another finger uses actions',
    (tester) async {
      final axes = <double>[];
      var actions = 0;
      await tester.pumpWidget(
        host(axes.add, MovementControlMode.joystick, onAction: () => actions++),
      );
      final center = tester.getCenter(find.byType(MoveJoystick));
      final first = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 1,
      );
      await first.moveTo(center + const Offset(40, 0));
      final second = await tester.startGesture(
        center - const Offset(20, 0),
        pointer: 2,
      );
      await second.up();
      await tester.tap(find.text('Action'), pointer: 3);
      expect(actions, 1);
      expect(axes, [1.0]);
      await first.cancel();
      expect(axes, [1.0, 0.0]);
    },
  );

  for (final mode in MovementControlMode.values) {
    testWidgets(
      '$mode clears a held gesture when disabled and needs a fresh press',
      (tester) async {
        final axes = <double>[];
        await tester.pumpWidget(host(axes.add, mode));
        final finder = mode == MovementControlMode.arrows
            ? find.byType(MoveButtons)
            : find.byType(MoveJoystick);
        final point = tester.getRect(finder).centerRight - const Offset(8, 0);
        final finger = await tester.startGesture(point);
        if (mode == MovementControlMode.joystick) {
          await finger.moveTo(point + const Offset(20, 0));
        }
        expect(axes.last, 1);
        await tester.pumpWidget(host(axes.add, mode, enabled: false));
        expect(axes.last, 0);
        await tester.pumpWidget(host(axes.add, mode));
        await finger.moveTo(point - const Offset(2, 0));
        await finger.up();
        expect(axes.last, 0);
        final fresh = await tester.startGesture(point);
        if (mode == MovementControlMode.joystick) {
          await fresh.moveTo(point + const Offset(20, 0));
        }
        expect(axes.last, 1);
        await fresh.up();
        expect(axes.last, 0);
      },
    );
  }

  testWidgets('changing presentation releases the previous held axis', (
    tester,
  ) async {
    final axes = <double>[];
    await tester.pumpWidget(host(axes.add, MovementControlMode.arrows));
    final finger = await tester.startGesture(
      tester.getRect(find.byType(MoveButtons)).centerRight - const Offset(8, 0),
    );
    expect(axes.last, 1);
    await tester.pumpWidget(host(axes.add, MovementControlMode.joystick));
    expect(axes.last, 0);
    expect(find.byType(MoveJoystick), findsOneWidget);
    await finger.up();
    expect(tester.takeException(), isNull);
  });
}
