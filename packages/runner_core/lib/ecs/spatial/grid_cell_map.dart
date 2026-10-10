/// Sparse exact cells without allocating or hashing coordinate pairs on lookup.
/// Integer lanes remain separate on every target. Clearing recycles row maps;
/// only currently occupied cells contribute to [length] and [values].
final class GridCellMap<T extends Object> {
  final _rows = <int, Map<int, T>>{};
  final _rowPool = <Map<int, T>>[];
  int _length = 0;

  int get length => _length;
  T? get(int x, int y) => _rows[y]?[x];

  T putIfAbsent(int x, int y, T Function() create) {
    var row = _rows[y];
    if (row == null) {
      row = _rowPool.isEmpty ? <int, T>{} : _rowPool.removeLast();
      _rows[y] = row;
    }
    final existing = row[x];
    if (existing != null) return existing;
    final value = create();
    row[x] = value;
    _length++;
    return value;
  }

  /// Storage iteration only; gameplay query ordering belongs to the caller.
  Iterable<T> get values sync* {
    for (final row in _rows.values) {
      yield* row.values;
    }
  }

  void clear() {
    for (final row in _rows.values) {
      row.clear();
      _rowPool.add(row);
    }
    _rows.clear();
    _length = 0;
  }
}
