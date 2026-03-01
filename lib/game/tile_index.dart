class TileLocation {
  const TileLocation({required this.sheet, required this.x, required this.y, this.w = 32, this.h = 32});
  final String sheet;
  final int x;  // pixel offset in sprite sheet (was col * 32, now raw)
  final int y;  // pixel offset in sprite sheet
  final int w;  // source width in pixels (ex - sx)
  final int h;  // source height in pixels (ey - sy)
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
    return TileLocation(sheet: fallbackSheet, x: 0, y: 0);
  }
}
