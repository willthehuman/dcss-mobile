class TileLocation {
  const TileLocation({
    required this.sheet,
    required this.col,
    required this.row,
  });

  final String sheet;
  final int col;
  final int row;
}

class TileIndexResolver {
  TileIndexResolver(Map<int, TileLocation> indexMap)
      : _indexMap = Map<int, TileLocation>.unmodifiable(indexMap);

  final Map<int, TileLocation> _indexMap;

  static const int tileSize = 32;

  TileLocation? resolve(int tileIndex) {
    return _indexMap[tileIndex];
  }

  bool contains(int tileIndex) {
    return _indexMap.containsKey(tileIndex);
  }

  int get length => _indexMap.length;

  Map<int, TileLocation> asMap() => _indexMap;

  TileLocation resolveOrFallback(int tileIndex, {String fallbackSheet = 'dungeon.png'}) {
    final TileLocation? resolved = resolve(tileIndex);
    if (resolved != null) {
      return resolved;
    }
    return TileLocation(sheet: fallbackSheet, col: 0, row: 0);
  }
}
