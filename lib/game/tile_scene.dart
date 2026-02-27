import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'tile_index.dart';

class TileScene extends FlameGame with TapCallbacks {
  TileScene({
    this.onTileTap,
  });

  final void Function(Point<int> point)? onTileTap;

  static const int _viewportTiles = 17;
  static const int _halfViewport = 8;

  final Map<String, SpriteComponent> _visibleComponents =
      <String, SpriteComponent>{};
  final Map<String, ui.Image> _sheetImages = <String, ui.Image>{};

  Map<Point<int>, List<int>> _tileGrid = const <Point<int>, List<int>>{};
  Point<int> _playerPos = const Point<int>(0, 0);

  TileIndexResolver _tileIndex = TileIndexResolver(const <int, TileLocation>{});

  double _tileScaleMultiplier = 1.0;
  bool _showGridLines = false;

  double _tileRenderSize = 32;
  Vector2 _viewportOrigin = Vector2.zero();

  final ui.Paint _gridPaint =
      ui.Paint()..color = const ui.Color(0x22FFFFFF)..strokeWidth = 1;
  final ui.Paint _playerPaint = ui.Paint()
    ..color = const ui.Color(0xBBFFFFFF)
    ..strokeWidth = 2
    ..style = ui.PaintingStyle.stroke;

  Future<void> setTileAssets({
    required Map<String, String> sheetPaths,
    required TileIndexResolver tileIndexResolver,
  }) async {
    _tileIndex = tileIndexResolver;

    final Map<String, ui.Image> loaded = <String, ui.Image>{};
    for (final MapEntry<String, String> entry in sheetPaths.entries) {
      final File file = File(entry.value);
      if (!await file.exists()) {
        continue;
      }
      try {
        final Uint8List bytes = await file.readAsBytes();
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        loaded[entry.key] = frameInfo.image;
      } catch (_) {
        // Skip invalid image files and continue.
      }
    }

    _sheetImages
      ..clear()
      ..addAll(loaded);

    _rebuildVisibleGrid();
  }

  void updateFromState({
    required Map<Point<int>, List<int>> tileGrid,
    required Point<int> playerPos,
    required double tileScaleMultiplier,
    required bool showGridLines,
  }) {
    _tileGrid = tileGrid;
    _playerPos = playerPos;
    _tileScaleMultiplier = tileScaleMultiplier;
    _showGridLines = showGridLines;

    _refreshLayout();
    _rebuildVisibleGrid();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _refreshLayout();
    _rebuildVisibleGrid();
  }

  @override
  void onTapDown(TapDownEvent event) {
    final double localX = event.localPosition.x - _viewportOrigin.x;
    final double localY = event.localPosition.y - _viewportOrigin.y;

    if (localX < 0 || localY < 0) {
      return;
    }

    final int col = (localX / _tileRenderSize).floor();
    final int row = (localY / _tileRenderSize).floor();

    if (col < 0 || col >= _viewportTiles || row < 0 || row >= _viewportTiles) {
      return;
    }

    final int worldX = _playerPos.x + col - _halfViewport;
    final int worldY = _playerPos.y + row - _halfViewport;
    onTileTap?.call(Point<int>(worldX, worldY));
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);

    if (_showGridLines) {
      _renderGridLines(canvas);
    }

    _renderPlayerHighlight(canvas);
  }

  void _refreshLayout() {
    if (size.x <= 0) {
      return;
    }

    final double baseTile = size.x / _viewportTiles;
    _tileRenderSize = baseTile * _tileScaleMultiplier;

    final double gridWidth = _tileRenderSize * _viewportTiles;
    final double gridHeight = gridWidth;

    _viewportOrigin = Vector2(
      (size.x - gridWidth) / 2,
      (size.y - gridHeight) / 2,
    );
  }

  void _rebuildVisibleGrid() {
    if (_tileRenderSize <= 0) {
      return;
    }

    for (final SpriteComponent component in _visibleComponents.values) {
      component.removeFromParent();
    }
    _visibleComponents.clear();

    for (int row = 0; row < _viewportTiles; row += 1) {
      for (int col = 0; col < _viewportTiles; col += 1) {
        final int worldX = _playerPos.x + col - _halfViewport;
        final int worldY = _playerPos.y + row - _halfViewport;
        final Point<int> point = Point<int>(worldX, worldY);

        final List<int>? stack = _tileGrid[point];
        if (stack == null || stack.isEmpty) {
          continue;
        }

        final int topTileIndex = stack.last;
        final Sprite? sprite = _resolveSprite(topTileIndex);
        if (sprite == null) {
          continue;
        }

        final SpriteComponent component = SpriteComponent(
          sprite: sprite,
          position: Vector2(
            _viewportOrigin.x + (col * _tileRenderSize),
            _viewportOrigin.y + (row * _tileRenderSize),
          ),
          size: Vector2.all(_tileRenderSize),
        );

        final String key = '$worldX:$worldY';
        _visibleComponents[key] = component;
        add(component);
      }
    }
  }

  Sprite? _resolveSprite(int tileIndex) {
    final TileLocation? location = _tileIndex.resolve(tileIndex);
    if (location == null) {
      return null;
    }

    final ui.Image? image = _sheetImages[location.sheet] ??
        _sheetImages['dungeon.png'] ??
        (_sheetImages.isNotEmpty ? _sheetImages.values.first : null);

    if (image == null) {
      return null;
    }

    final double sourceX = location.col * TileIndexResolver.tileSize.toDouble();
    final double sourceY = location.row * TileIndexResolver.tileSize.toDouble();

    return Sprite(
      image,
      srcPosition: Vector2(sourceX, sourceY),
      srcSize: Vector2.all(TileIndexResolver.tileSize.toDouble()),
    );
  }

  void _renderGridLines(ui.Canvas canvas) {
    final double width = _tileRenderSize * _viewportTiles;
    final double height = width;

    for (int i = 0; i <= _viewportTiles; i += 1) {
      final double dx = _viewportOrigin.x + (i * _tileRenderSize);
      final double dy = _viewportOrigin.y + (i * _tileRenderSize);

      canvas.drawLine(
        ui.Offset(dx, _viewportOrigin.y),
        ui.Offset(dx, _viewportOrigin.y + height),
        _gridPaint,
      );
      canvas.drawLine(
        ui.Offset(_viewportOrigin.x, dy),
        ui.Offset(_viewportOrigin.x + width, dy),
        _gridPaint,
      );
    }
  }

  void _renderPlayerHighlight(ui.Canvas canvas) {
    final double left = _viewportOrigin.x + (_halfViewport * _tileRenderSize);
    final double top = _viewportOrigin.y + (_halfViewport * _tileRenderSize);

    canvas.drawRect(
      ui.Rect.fromLTWH(left, top, _tileRenderSize, _tileRenderSize),
      _playerPaint,
    );
  }
}
