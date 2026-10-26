import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/run/run_release_gate.dart';
import 'package:rpg_runner/ui/state/run/run_start_remote_exception.dart';

void main() {
  const update = RunStartRemoteException(
    code: 'failed-precondition',
    details: {'reason': 'update-required'},
  );
  const maintenance = RunStartRemoteException(
    code: 'unavailable',
    details: {'reason': 'release-maintenance'},
  );

  test('only the structured server rejection selects a release gate', () {
    expect(update.isUpdateRequired, isTrue);
    expect(maintenance.isReleaseMaintenance, isTrue);
    expect(
      const RunStartRemoteException(code: 'unavailable').isReleaseMaintenance,
      isFalse,
    );
    expect(
      const RunStartRemoteException(
        code: 'failed-precondition',
        details: {'reason': 'release-maintenance'},
      ).isReleaseMaintenance,
      isFalse,
    );
    expect(
      const RunStartRemoteException(
        code: 'failed-precondition',
        details: 'update-required',
      ).isUpdateRequired,
      isFalse,
    );
  });

  for (final opens in [false, true]) {
    testWidgets('store outcome $opens cannot bypass the update gate', (
      tester,
    ) async {
      final opened = <Uri>[];
      var retries = 0;
      final store = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.lothringen.longrun.staging',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RunReleaseGate(
              error: update,
              storeUri: store,
              onRetry: () => retries++,
              openUrl: (uri) async {
                opened.add(uri);
                return opens;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Google Play'));
      await tester.pumpAndSettle();
      expect(opened, [store]);
      expect(retries, 0);
      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      if (!opens) {
        expect(find.textContaining('Unable to open the link.'), findsOneWidget);
      }
      await tester.tap(find.text('Contact support'));
      await tester.pumpAndSettle();
      expect(opened.last, Uri.parse('mailto:lothringen.rpg@gmail.com'));
    });
  }

  testWidgets(
    'maintenance retries the server without sending players to the store',
    (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RunReleaseGate(error: maintenance, onRetry: () => retries++),
          ),
        ),
      );
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Open Google Play'), findsNothing);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    },
  );
}
