import 'authoring_types.dart';

/// Indexes authoring plugins by stable plugin id for session/runtime lookup.
///
/// Constructor input order is preserved for [all] as long as plugin ids are
/// unique. If duplicate ids are provided, later entries overwrite earlier ones.
class AuthoringPluginRegistry {
  /// Builds an id-indexed registry from the provided plugin list.
  AuthoringPluginRegistry({required List<AuthoringDomainPlugin> plugins})
    : _pluginsById = {for (final plugin in plugins) plugin.id: plugin};

  final Map<String, AuthoringDomainPlugin> _pluginsById;

  /// Returns all registered plugins as a non-growable snapshot.
  List<AuthoringDomainPlugin> get all =>
      _pluginsById.values.toList(growable: false);

  /// Returns the plugin for [id], or null when no plugin is registered.
  AuthoringDomainPlugin? findById(String id) => _pluginsById[id];

  /// Returns the plugin for [id], or throws when the id is unknown.
  ///
  /// Use this in flows where missing plugins are a configuration/runtime error.
  AuthoringDomainPlugin requireById(String id) {
    final plugin = findById(id);
    if (plugin == null) {
      throw StateError('Unknown authoring plugin id: $id');
    }
    return plugin;
  }
}
