import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localization.dart';

abstract interface class LocaleSettingsStore {
  /// Returns the saved BCP-47 tag, or null for absent/malformed preferences.
  Future<String?> loadLanguage();

  /// Completes only after persistence succeeds; failures leave the choice intact.
  Future<void> saveLanguage(String languageTag);
}

/// Device preference; independent of authenticated and Developer Practice data.
class SharedPrefsLocaleSettingsStore implements LocaleSettingsStore {
  static const _key = 'ui.language.v1';

  @override
  Future<String?> loadLanguage() async {
    final value = (await SharedPreferences.getInstance()).get(_key);
    return value is String ? value : null;
  }

  @override
  Future<void> saveLanguage(String languageTag) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      _key,
      languageTag,
    )) {
      throw StateError('Could not persist language preference.');
    }
  }
}

/// App-owned locale, restored before service bootstrap. Writes publish only on
/// success; disposal fences late completions. No store means in-memory embedding.
class LocaleSettings extends ChangeNotifier {
  LocaleSettings({LocaleSettingsStore? store}) : _store = store;

  final LocaleSettingsStore? _store;
  Locale _locale = const Locale('en');
  bool _loaded = false;
  bool _saving = false;
  bool _disposed = false;
  Future<void>? _loading;

  Locale get locale => _locale;
  bool get isSaving => _saving;

  Future<void> load() async {
    if (_disposed || _loaded) return;
    final pending = _loading ??= _restore();
    try {
      await pending;
    } finally {
      if (identical(_loading, pending)) _loading = null;
    }
  }

  Future<void> _restore() async {
    final code = await _store?.loadLanguage();
    if (_disposed) return;
    _locale = AppLocalizations.supportedLocales.firstWhere(
      (locale) => locale.toLanguageTag() == code,
      orElse: () => const Locale('en'),
    );
    _loaded = true;
    notifyListeners();
  }

  /// Rejects unsupported choices. A failed write leaves the visible language
  /// unchanged and permits retry; concurrent writes are never reordered.
  Future<void> setLocale(Locale locale) async {
    if (_disposed) return;
    if (!AppLocalizations.supportedLocales.contains(locale)) {
      throw ArgumentError.value(locale, 'locale', 'Unsupported language.');
    }
    if (_saving) throw StateError('Language preference is already saving.');
    await load();
    if (_disposed || locale == _locale) return;
    if (_saving) throw StateError('Language preference is already saving.');
    _saving = true;
    notifyListeners();
    try {
      await _store?.saveLanguage(locale.toLanguageTag());
      if (!_disposed) _locale = locale;
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
