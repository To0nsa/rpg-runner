import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_runner/ui/app/app_services.dart';
import 'package:rpg_runner/ui/controls/movement_control_mode.dart';
import 'package:rpg_runner/ui/pages/options/options_page.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/settings/control_settings.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../test_support/app_startup_fakes.dart';

void main() {
  testWidgets(
    'settings links and movement controls remain usable on small screens',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fixture = StartupFixture();
      final store = SharedPrefsControlSettingsStore();
      final services = AppServices(
        initialize: () async {},
        createAppState: () => AppState(
          authApi: fixture.auth,
          userProfileRemoteApi: fixture.profile,
          loadoutOwnershipApi: fixture.ownership,
        ),
        controlSettingsStore: store,
      );
      addTearDown(services.dispose);
      final state = await services.initialize();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(480, 320);
      final opened = <Uri>[];
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppServices>.value(value: services),
            ChangeNotifierProvider<AppState>.value(value: state),
          ],
          child: MaterialApp(
            theme: createUiTheme(),
            home: OptionsPage(
              openUrl: (uri) async {
                opened.add(uri);
                return false;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Privacy policy'));
      await tester.pumpAndSettle();
      expect(
        opened.single,
        Uri.parse('https://rpg-runner-d7add.web.app/privacy-policy.html'),
      );
      expect(find.textContaining('You can open it manually.'), findsOneWidget);
      await tester.tap(find.text('Contact support'));
      await tester.pumpAndSettle();
      expect(opened.last, Uri.parse('mailto:lothringen.rpg@gmail.com'));
      await tester.tap(find.text('CONTROLS'));
      await tester.pumpAndSettle();
      for (final size in [const Size(480, 320), const Size(800, 480)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        for (final (label, mode) in [
          ('Floating joystick', MovementControlMode.joystick),
          ('Fixed joystick', MovementControlMode.fixedJoystick),
          ('Arrows', MovementControlMode.arrows),
        ]) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(services.controlSettings.movementMode, mode);
          expect(await store.loadMovementMode(), mode);
          expect(
            tester
                .widget<SegmentedButton<MovementControlMode>>(
                  find.byType(SegmentedButton<MovementControlMode>),
                )
                .selected,
            {mode},
          );
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
