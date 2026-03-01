import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import 'tile_index.dart';

class TileScene extends FlameGame with TapCallbacks {
  TileScene({
    this.onTileTap,
  });

  final void Function(Point<int> point)? onTileTap;

  static const int _viewportTiles = 17;
  static const int _halfViewport = 8;

  // final List<Component> _managedComponents = <Component>[];
  final Map<String, ui.Image> _sheetImages = <String, ui.Image>{};

  Map<Point<int>, List<int>> _tileGrid = const <Point<int>, List<int>>{};
  Point<int> _playerPos = const Point<int>(0, 0);
  Point<int>? _cursorPos;

  TileIndexResolver _tileIndex = TileIndexResolver(const <int, TileLocation>{});

  double _tileScaleMultiplier = 1.0;
  bool _showGridLines = false;

  double _tileRenderSize = 32;
  Vector2 _viewportOrigin = Vector2.zero();

  final ui.Paint _gridPaint = ui.Paint()
    ..color = const ui.Color(0x22FFFFFF)
    ..strokeWidth = 1;
  final ui.Paint _playerPaint = ui.Paint()
    ..color = const ui.Color(0xBBFFFFFF)
    ..strokeWidth = 2
    ..style = ui.PaintingStyle.stroke;
  final ui.Paint _cursorPaint = ui.Paint()
    ..color = const ui.Color(0xBB00FF00)
    ..strokeWidth = 2
    ..style = ui.PaintingStyle.stroke;

  Future<void> setTileAssets({
    required Map<String, String> sheetPaths,
    required TileIndexResolver tileIndexResolver,
  }) async {
    _tileIndex = tileIndexResolver;
    final Map<String, ui.Image> loaded = {};
    for (final entry in sheetPaths.entries) {
      final file = File(entry.value);
      if (!await file.exists()) continue;
      try {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        loaded[entry.key] = frame.image;
      } catch (e) {
        debugPrint(
            '[TileScene] failed to load ${entry.key}: $e'); // was silent!
      }
    }
    _sheetImages
      ..clear()
      ..addAll(loaded);
    debugPrint(
        '[TileScene] setTileAssets complete: ${_sheetImages.length} sheets loaded');
    // _rebuildVisibleGrid(); // now _sheetImages is populated
  }

  void updateFromState({
    required Map<Point<int>, List<int>> tileGrid,
    required Point<int> playerPos,
    required Point<int>? cursorPos,
    required double tileScaleMultiplier,
    required bool showGridLines,
  }) {
    _tileGrid = tileGrid;
    _playerPos = playerPos;
    _cursorPos = cursorPos;
    _tileScaleMultiplier = tileScaleMultiplier;
    _showGridLines = showGridLines;

    _refreshLayout();
    // _rebuildVisibleGrid();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _refreshLayout();
    // _rebuildVisibleGrid();
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
    _renderTiles(canvas); // ← draw directly, no add/remove
    if (_showGridLines) _renderGridLines(canvas);
    _renderPlayerHighlight(canvas);
    _renderCursorReticle(canvas);
  }

  void _renderTiles(ui.Canvas canvas) {
    for (int row = 0; row < _viewportTiles; row++) {
      for (int col = 0; col < _viewportTiles; col++) {
        final worldX = _playerPos.x + col - _halfViewport;
        final worldY = _playerPos.y + row - _halfViewport;
        final stack = _tileGrid[Point<int>(worldX, worldY)];

        final dst = Rect.fromLTWH(
          _viewportOrigin.x + col * _tileRenderSize,
          _viewportOrigin.y + row * _tileRenderSize,
          _tileRenderSize,
          _tileRenderSize,
        );

        bool anyRendered = false;
        if (stack != null) {
          // stack[0] is always the mf prefix (positive for visible cells,
          // negative for remembered cells). Skip it when rendering tiles so
          // small mf values (e.g. 1 = floor terrain) are never mistakenly
          // resolved as tile indices.
          for (int i = 1; i < stack.length; i++) {
            final int tileIndex = stack[i];
            if (tileIndex < 0) continue;
            final loc = _tileIndex.resolve(tileIndex);
            if (loc == null) continue;
            final image = _sheetImages[loc.sheet];
            if (image == null) continue;
            final src = Rect.fromLTWH(
              loc.x.toDouble(),
              loc.y.toDouble(),
              loc.w.toDouble(),
              loc.h.toDouble(),
            );
            final double scale = _tileRenderSize / 32.0;

            double ox = loc.ox * scale;
            double oy = loc.oy * scale;

            double renderW = loc.w * scale;
            double renderH = loc.h * scale;

            // Icons (like `?` when spotted) should be rendered small at the
            // top-right corner of the cell so they're visible above the monster.
            if (loc.sheet.contains('icon')) {
              final double iconScale = _tileRenderSize * 0.45;
              renderW = iconScale;
              renderH = iconScale;
              ox = _tileRenderSize - iconScale; // align right
              oy = 0; // align top
            }

            final partDst = Rect.fromLTWH(
              _viewportOrigin.x + col * _tileRenderSize + ox,
              _viewportOrigin.y + row * _tileRenderSize + oy,
              renderW,
              renderH,
            );
            canvas.drawImageRect(image, src, partDst, Paint());
            anyRendered = true;
          }
          if (!anyRendered && stack.isNotEmpty && stack.first < 0) {
            canvas.drawRect(dst, Paint()..color = _mfColor(-stack.first - 1));
          }
          // For remembered/out-of-sight cells, draw a semi-transparent dark
          // overlay over the rendered sprites so they appear dimmed.
          if (anyRendered && stack.isNotEmpty && stack.first < 0) {
            canvas.drawRect(dst, Paint()..color = _rememberedCellOverlay);
          }
        }
      }
    }
  }

  void _refreshLayout() {
    if (!hasLayout || size.x <= 0) {
      // ← add !hasLayout check
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

  // void _rebuildVisibleGrid() {
  //   if (_tileRenderSize <= 0) return;

  //   debugPrint(
  //       '[TileScene] rebuilding grid: ${_tileGrid.length} cells, playerPos: $_playerPos');

  //   // Remove ALL previously added tile components
  //   for (final Component c in _managedComponents) {
  //     c.removeFromParent();
  //   }
  //   _managedComponents.clear();

  //   for (int row = 0; row < _viewportTiles; row += 1) {
  //     for (int col = 0; col < _viewportTiles; col += 1) {
  //       final int worldX = _playerPos.x + col - _halfViewport;
  //       final int worldY = _playerPos.y + row - _halfViewport;
  //       final Point<int> point = Point<int>(worldX, worldY);

  //       final List<int>? stack = _tileGrid[point];
  //       if (stack == null || stack.isEmpty) continue;

  //       bool anyRendered = false;

  //       for (final int tileIndex in stack) {
  //         if (tileIndex < 0) continue;

  //         final Sprite? sprite = _resolveSprite(tileIndex);
  //         if (sprite == null) continue;

  //         final SpriteComponent sc = SpriteComponent(
  //           sprite: sprite,
  //           position: Vector2(
  //             _viewportOrigin.x + (col * _tileRenderSize),
  //             _viewportOrigin.y + (row * _tileRenderSize),
  //           ),
  //           size: Vector2.all(_tileRenderSize),
  //         );
  //         _managedComponents.add(sc);
  //         add(sc);
  //         anyRendered = true;
  //       }

  //       if (!anyRendered) {
  //         final int mf =
  //             (stack.isNotEmpty && stack.first < 0) ? -stack.first : 0;
  //         final Color fallback = _mfColor(mf);
  //         final RectangleComponent rc = RectangleComponent(
  //           position: Vector2(
  //             _viewportOrigin.x + (col * _tileRenderSize),
  //             _viewportOrigin.y + (row * _tileRenderSize),
  //           ),
  //           size: Vector2.all(_tileRenderSize),
  //           paint: Paint()..color = fallback,
  //         );
  //         _managedComponents.add(rc);
  //         add(rc);
  //       }
  //     }
  //   }
  // }

  // Sprite? _resolveSprite(int tileIndex) {
  //   final TileLocation? location = _tileIndex.resolve(tileIndex);
  //   if (location == null) {
  //     return null;
  //   }

  //   final ui.Image? image = _sheetImages[location.sheet];

  //   if (image == null) {
  //     return null;
  //   }

  //   final double srcX = location.x.toDouble();
  //   final double srcY = location.y.toDouble();

  //   return Sprite(
  //     image,
  //     srcPosition: Vector2(srcX, srcY),
  //     srcSize: Vector2.all(TileIndexResolver.tileSize.toDouble()),
  //   );
  // }

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

  void _renderCursorReticle(ui.Canvas canvas) {
    if (_cursorPos == null) {
      return;
    }

    final int col = _cursorPos!.x - _playerPos.x + _halfViewport;
    final int row = _cursorPos!.y - _playerPos.y + _halfViewport;

    if (col < 0 || col >= _viewportTiles || row < 0 || row >= _viewportTiles) {
      return;
    }

    final double left = _viewportOrigin.x + (col * _tileRenderSize);
    final double top = _viewportOrigin.y + (row * _tileRenderSize);

    canvas.drawRect(
      ui.Rect.fromLTWH(left, top, _tileRenderSize, _tileRenderSize),
      _cursorPaint,
    );

    final double centerX = left + _tileRenderSize / 2;
    final double centerY = top + _tileRenderSize / 2;
    final double arm = _tileRenderSize / 4;

    canvas.drawLine(
      ui.Offset(centerX - arm, centerY),
      ui.Offset(centerX + arm, centerY),
      _cursorPaint,
    );
    canvas.drawLine(
      ui.Offset(centerX, centerY - arm),
      ui.Offset(centerX, centerY + arm),
      _cursorPaint,
    );
  }

  static const Color _rememberedCellOverlay = Color(0x88000000);

  static Color _mfColor(int mf) {
    switch (mf) {
      case 1:
        return const Color(0xFF4A4A4A); // floor — dark gray
      case 2:
        return const Color(0xFF2A1A0A); // wall — dark brown
      case 5:
        return const Color(0xFF8B6914); // door — tan
      case 12:
      case 13:
        return const Color(0xFF005588); // stairs — blue
      case 16:
        return const Color(0xFF1A3A6A); // shallow water
      case 17:
        return const Color(0xFFAA2200); // lava
      case 26:
        return const Color(0xFF111111); // unexplored — near black
      default:
        return const Color(0xFF333333); // unknown — dark
    }
  }
}
