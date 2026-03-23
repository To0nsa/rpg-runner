import 'authoring_types.dart';

class AuthoringPluginRegistry {
  AuthoringPluginRegistry({required List<AuthoringDomainPlugin> plugins})
    : _pluginsById = {for (final plugin in plugins) plugin.id: plugin};

  final Map<String, AuthoringDomainPlugin> _pluginsById;

  List<AuthoringDomainPlugin> get all =>
      _pluginsById.values.toList(growable: false);

  AuthoringDomainPlugin? findById(String id) => _pluginsById[id];

  AuthoringDomainPlugin requireById(String id) {
    final plugin = findById(id);
    if (plugin == null) {
      throw StateError('Unknown authoring plugin id: $id');
    }
    return plugin;
  }
}
