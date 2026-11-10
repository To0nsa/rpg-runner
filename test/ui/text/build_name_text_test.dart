import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';
import 'package:rpg_runner/ui/text/build_name_text.dart';

void main() {
  test(
    'reserved defaults localize without changing custom names or persistence',
    () {
      final fr = appStringsFor(const Locale('fr'));
      final en = appStringsFor(const Locale('en'));
      final stored = SelectionState.defaultBuildName(1);
      expect(buildDisplayName(stored, 1, en), 'Build 2');
      expect(buildDisplayName(stored, 1, fr), fr.defaultBuildName(number: 2));
      for (final name in ['My build', 'Éclaireuse', 'Build 20', 'Build 1']) {
        expect(buildDisplayName(name, 1, fr), name);
      }
      expect(SelectionState.defaultBuildName(1), stored);
    },
  );
}
