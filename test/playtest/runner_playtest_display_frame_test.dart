import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/playtest.dart';
import 'package:rpg_runner/playtest/runner_playtest_display_frame.dart';

void main() {
  testWidgets('device geometry preserves ambient accessibility preferences', (
    tester,
  ) async {
    MediaQueryData? media;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.4),
            disableAnimations: true,
            accessibleNavigation: true,
            padding: EdgeInsets.all(25),
            viewPadding: EdgeInsets.all(25),
          ),
          child: RunnerPlaytestDisplayFrame(
            display: RunnerPlaytestDevicePresets.defaultPhone,
            child: Builder(
              builder: (context) {
                media = MediaQuery.of(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    expect(media!.textScaler.scale(10), 14);
    expect(media!.disableAnimations, isTrue);
    expect(media!.accessibleNavigation, isTrue);
    expect(media!.padding, EdgeInsets.zero);
    expect(media!.viewPadding, EdgeInsets.zero);
  });

  for (final preset in RunnerPlaytestDevicePresets.devices.entries) {
    testWidgets(
      '${preset.key} preserves its logical display and maps scaled taps',
      (tester) async {
        final device = preset.value;
        final surfaceKey = GlobalKey();
        Offset? pointer;
        MediaQueryData? media;
        Size? constraintsSize;
        await tester.pumpWidget(
          MaterialApp(
            home: RunnerPlaytestDisplayFrame(
              display: device,
              scale: 0.75,
              child: Builder(
                builder: (context) {
                  media = MediaQuery.of(context);
                  return LayoutBuilder(
                    builder: (_, constraints) {
                      constraintsSize = constraints.biggest;
                      return Listener(
                        key: surfaceKey,
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (event) => pointer = event.localPosition,
                        child: const SizedBox.expand(),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final (size, dpr) in [
          (const Size(1770, 797), 1.0),
          (const Size(640, 480), 1.25),
        ]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = dpr;
          await tester.pump();
          expect(constraintsSize, device.size);
          expect(media!.size, device.size);
          expect(media!.devicePixelRatio, device.devicePixelRatio);
          expect(media!.padding, EdgeInsets.zero);
          expect(media!.viewInsets, EdgeInsets.zero);
          final box =
              surfaceKey.currentContext!.findRenderObject()! as RenderBox;
          final bounds = Rect.fromPoints(
            box.localToGlobal(Offset.zero),
            box.localToGlobal(device.size.bottomRight(Offset.zero)),
          );
          final available = size / dpr;
          expect(
            bounds.width / bounds.height,
            closeTo(device.width / device.height, 1e-8),
          );
          expect(bounds.left, greaterThanOrEqualTo(-1e-8));
          expect(bounds.top, greaterThanOrEqualTo(-1e-8));
          expect(bounds.width, closeTo(device.width * .75, 1e-6));
          expect(bounds.height, closeTo(device.height * .75, 1e-6));
          // A smaller editor clips/scrolls the same physical-size rectangle.
          expect(
            bounds.right > available.width,
            device.width * .75 > available.width,
          );
          final localTarget = Offset(device.width * .2, device.height * .2);
          await tester.tapAt(box.localToGlobal(localTarget));
          expect(pointer!.dx, closeTo(localTarget.dx, 1e-6));
          expect(pointer!.dy, closeTo(localTarget.dy, 1e-6));
          pointer = null;
          // A letterbox click is outside the simulated display/input surface.
          if (bounds.top > 1e-6 || bounds.left > 1e-6) {
            final margin = bounds.top > 1e-6
                ? Offset(bounds.center.dx, bounds.top / 2)
                : Offset(bounds.left / 2, bounds.center.dy);
            await tester.tapAt(margin);
            expect(pointer, isNull);
          }
        }
      },
    );
  }
}
