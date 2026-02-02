import 'dart:collection';

typedef EvictCallback<V> = void Function(V value);

/// Small, allocation-light LRU cache with optional eviction callback.
class LruCache<K, V> {
  LruCache({required int maxEntries, this.onEvict})
      : _maxEntries = maxEntries < 0 ? 0 : maxEntries;

  final int _maxEntries;
  final EvictCallback<V>? onEvict;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  int get length => _map.length;

  Iterable<V> get values => _map.values;

  V? get(K key) {
    final value = _map.remove(key);
    if (value == null) return null;
    _map[key] = value;
    return value;
  }

  void put(K key, V value) {
    final existing = _map.remove(key);
    if (existing != null && !identical(existing, value)) {
      onEvict?.call(existing);
    }
    _map[key] = value;
    trim();
  }

  bool containsKey(K key) => _map.containsKey(key);

  void remove(K key) {
    final value = _map.remove(key);
    if (value != null) {
      onEvict?.call(value);
    }
  }

  void clear() {
    if (onEvict != null) {
      for (final value in _map.values) {
        onEvict!(value);
      }
    }
    _map.clear();
  }

  void trim() {
    if (_maxEntries <= 0) {
      clear();
      return;
    }
    while (_map.length > _maxEntries) {
      final entry = _map.entries.first;
      _map.remove(entry.key);
      onEvict?.call(entry.value);
    }
  }
}
