import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rpg_runner/ui/app/ui_app.dart';

void main() {
  testWidgets('cold launch shows loader then hub', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const UiApp());
    expect(find.text('Loading...'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('PLAY HUB'), findsOneWidget);
  });
}
