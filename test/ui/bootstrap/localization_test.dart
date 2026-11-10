import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/app/ui_app.dart';
import 'package:rpg_runner/ui/components/app_inline_edit_text.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:rpg_runner/ui/pages/options/options_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_support/app_startup_fakes.dart';

void main() {
  testWidgets(
    'an existing save error follows locale without resubmitting or losing input',
    (tester) async {
      var commits = 0;
      Widget host(Locale locale) => MaterialApp(
        locale: locale,
        localizationsDelegates: RunnerLocalizations.delegates,
        supportedLocales: RunnerLocalizations.supportedLocales,
        theme: createUiTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => AppInlineEditText(
              text: 'My name',
              displayText: 'My name',
              hintText: context.l10n.uiEnterName,
              onCommit: (_) async {
                commits++;
                throw StateError('offline');
              },
              errorTextFromError: (_) =>
                  context.l10n.uiCouldNotSaveTheNamePleaseTryAgain,
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(const Locale('en')));
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text(appStringsFor(null).uiCouldNotSaveTheNamePleaseTryAgain),
        findsOneWidget,
      );
      await tester.pumpWidget(host(const Locale('fr')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          appStringsFor(const Locale('fr')).uiCouldNotSaveTheNamePleaseTryAgain,
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'My name',
      );
      expect(commits, 1);
    },
  );
  testWidgets('app language changes preserve the navigator and mounted route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final fixture = StartupFixture();
    await tester.pumpWidget(UiApp(services: fixture.services));
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    final state = fixture.services.appState;
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final routeKey = GlobalKey();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (context) =>
            Scaffold(key: routeKey, body: Text(context.l10n.languageLabel)),
      ),
    );
    await tester.pumpAndSettle();
    final element = routeKey.currentContext;
    expect(find.text('Language'), findsOneWidget);
    await fixture.services.localeSettings.setLocale(const Locale('fr'));
    await tester.pumpAndSettle();
    expect(find.text('Langue'), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)),
      same(navigator),
    );
    expect(routeKey.currentContext, same(element));
    expect(fixture.services.appState, same(state));
    expect(fixture.stateCreations, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('embedding fallback respects inherited language variants', (
    tester,
  ) async {
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('fr', 'CA'),
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) => Text(context.l10n.languageLabel),
          ),
        ),
      ),
    );
    expect(find.text('Langue'), findsOneWidget);
    expect(resolveAppLocale(const Locale('de')), const Locale('en'));
  });

  testWidgets('French Options stays usable on compact landscape screens', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(480, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = StartupFixture();
    await tester.pumpWidget(UiApp(services: fixture.services));
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const OptionsPage()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(find.text('PARAMÈTRES'), findsOneWidget);
    expect(find.text('Langue'), findsOneWidget);
    await tester.tap(find.text('COMMANDES'));
    await tester.pumpAndSettle();
    expect(find.text('Joystick flottant'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
