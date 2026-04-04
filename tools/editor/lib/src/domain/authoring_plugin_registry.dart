import 'authoring_types.dart';

/// Indexes authoring plugins by stable plugin id for session/runtime lookup.
///
/// Constructor input order is preserved for [all].
///
/// Plugin ids must be unique. Duplicate ids are treated as configuration
/// errors and fail fast during registry construction.
class AuthoringPluginRegistry {
  /// Builds an id-indexed registry from the provided plugin list.
  AuthoringPluginRegistry({required List<AuthoringDomainPlugin> plugins})
    : _pluginsById = _buildPluginMap(plugins);

  final Map<String, AuthoringDomainPlugin> _pluginsById;

  static Map<String, AuthoringDomainPlugin> _buildPluginMap(
    List<AuthoringDomainPlugin> plugins,
  ) {
    final pluginsById = <String, AuthoringDomainPlugin>{};
    for (final plugin in plugins) {
      final existing = pluginsById[plugin.id];
      if (existing != null) {
        throw StateError(
          'Duplicate authoring plugin id "${plugin.id}" '
          '(${existing.runtimeType} and ${plugin.runtimeType}).',
        );
      }
      pluginsById[plugin.id] = plugin;
    }
    return pluginsById;
  }

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
