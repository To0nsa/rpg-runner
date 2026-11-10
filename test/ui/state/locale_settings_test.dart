import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/state/settings/locale_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'absent, unsupported and malformed preferences safely use English',
    () async {
      for (final raw in [null, '', 'de', 'fr-CA', 42]) {
        SharedPreferences.setMockInitialValues({'ui.language.v1': ?raw});
        final settings = LocaleSettings(
          store: SharedPrefsLocaleSettingsStore(),
        );
        await settings.load();
        expect(settings.locale, const Locale('en'));
        settings.dispose();
      }
    },
  );

  test(
    'French survives recreation and English can be restored explicitly',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsLocaleSettingsStore();
      final first = LocaleSettings(store: store);
      await first.setLocale(const Locale('fr'));
      first.dispose();
      final restored = LocaleSettings(store: store);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.locale, const Locale('fr'));
      await restored.setLocale(const Locale('en'));
      expect(await store.loadLanguage(), 'en');
      await expectLater(
        restored.setLocale(const Locale('de')),
        throwsArgumentError,
      );
      expect(await store.loadLanguage(), 'en');
    },
  );

  test(
    'failed writes retain language; concurrent writes cannot reorder it',
    () async {
      final store = _Store();
      final settings = LocaleSettings(store: store);
      addTearDown(settings.dispose);
      await settings.load();
      final pending = settings.setLocale(const Locale('fr'));
      await Future<void>.delayed(Duration.zero);
      expect(settings.isSaving, isTrue);
      expect(settings.locale, const Locale('en'));
      await expectLater(
        settings.setLocale(const Locale('en')),
        throwsStateError,
      );
      final failed = expectLater(pending, throwsStateError);
      store.write.completeError(StateError('disk full'));
      await failed;
      expect(settings.isSaving, isFalse);
      expect(settings.locale, const Locale('en'));
      store.write = Completer<void>();
      final retry = settings.setLocale(const Locale('fr'));
      store.write.complete();
      await retry;
      expect(settings.locale, const Locale('fr'));
    },
  );

  test('disposal prevents publishing a late successful write', () async {
    final store = _Store();
    final settings = LocaleSettings(store: store);
    await settings.load();
    final pending = settings.setLocale(const Locale('fr'));
    await Future<void>.delayed(Duration.zero);
    settings.dispose();
    store.write.complete();
    await pending;
    expect(settings.locale, const Locale('en'));
  });
}

class _Store implements LocaleSettingsStore {
  Completer<void> write = Completer<void>();
  @override
  Future<String?> loadLanguage() async => null;
  @override
  Future<void> saveLanguage(String languageCode) => write.future;
}
