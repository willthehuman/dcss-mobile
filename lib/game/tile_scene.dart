import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import 'tile_index.dart';

// dart:io File is only used on native.
import 'tile_scene_io.dart'
    if (dart.library.html) 'tile_scene_web.dart';

class TileScene extends FlameGame with TapCallbacks {
  TileScene({
    this.onTileTap,
  });

  final void Function(Point<int> point)? onTileTap;

  static const int _viewportTiles = 17;
  static const int _halfViewport = 8;

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

  /// Load tile sheet images from either file paths (native) or raw bytes (web).
  Future<void> setTileAssets({
    required Map<String, String> sheetPaths,
    required Map<String, List<int>> sheetBytes,
    required TileIndexResolver tileIndexResolver,
  }) async {
    _tileIndex = tileIndexResolver;
    final Map<String, ui.Image> loaded = <String, ui.Image>{};

    if (kIsWeb) {
      // Web: decode from in-memory bytes.
      for (final MapEntry<String, List<int>> entry in sheetBytes.entries) {
        try {
          final ui.Codec codec = await ui.instantiateImageCodec(
              Uint8List.fromList(entry.value));
          final ui.FrameInfo frame = await codec.getNextFrame();
          loaded[entry.key] = frame.image;
        } catch (e) {
          debugPrint('[TileScene] web: failed to decode ${entry.key}: $e');
        }
      }
    } else {
      // Native: read from cached files on disk.
      await loadSheetImagesFromFiles(sheetPaths, loaded);
    }

    _sheetImages
      ..clear()
      ..addAll(loaded);
    debugPrint(
        '[TileScene] setTileAssets: ${_sheetImages.length} sheets loaded');
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
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _refreshLayout();
  }

  @override
  void onTapDown(TapDownEvent event) {
    final double localX = event.localPosition.x - _viewportOrigin.x;
    final double localY = event.localPosition.y - _viewportOrigin.y;
    if (localX < 0 || localY < 0) return;
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
    _renderTiles(canvas);
    if (_showGridLines) _renderGridLines(canvas);
    _renderPlayerHighlight(canvas);
    _renderCursorReticle(canvas);
  }

  void _renderTiles(ui.Canvas canvas) {
    for (int row = 0; row < _viewportTiles; row++) {
      for (int col = 0; col < _viewportTiles; col++) {
        final int worldX = _playerPos.x + col - _halfViewport;
        final int worldY = _playerPos.y + row - _halfViewport;
        final List<int>? stack = _tileGrid[Point<int>(worldX, worldY)];

        final Rect dst = Rect.fromLTWH(
          _viewportOrigin.x + col * _tileRenderSize,
          _viewportOrigin.y + row * _tileRenderSize,
          _tileRenderSize,
          _tileRenderSize,
        );

        bool anyRendered = false;
        if (stack != null) {
          for (int i = 1; i < stack.length; i++) {
            final int tileIndex = stack[i];
            if (tileIndex < 0) continue;
            final TileLocation? loc = _tileIndex.resolve(tileIndex);
            if (loc == null) continue;
            final ui.Image? image = _sheetImages[loc.sheet];
            if (image == null) continue;
            final Rect src = Rect.fromLTWH(
              loc.x.toDouble(), loc.y.toDouble(),
              loc.w.toDouble(), loc.h.toDouble(),
            );
            final double scale = _tileRenderSize / 32.0;
            double ox = loc.ox * scale;
            double oy = loc.oy * scale;
            double renderW = loc.w * scale;
            double renderH = loc.h * scale;
            if (loc.sheet.contains('icon')) {
              final double iconScale = _tileRenderSize * 0.45;
              renderW = iconScale;
              renderH = iconScale;
              ox = _tileRenderSize - iconScale;
              oy = 0;
            }
            final Rect partDst = Rect.fromLTWH(
              _viewportOrigin.x + col * _tileRenderSize + ox,
              _viewportOrigin.y + row * _tileRenderSize + oy,
              renderW, renderH,
            );
            canvas.drawImageRect(image, src, partDst, Paint());
            anyRendered = true;
          }
          if (!anyRendered && stack.isNotEmpty && stack.first < 0) {
            canvas.drawRect(dst, Paint()..color = _mfColor(-stack.first - 1));
          }
          if (anyRendered && stack.isNotEmpty && stack.first < 0) {
            canvas.drawRect(dst, Paint()..color = _rememberedCellOverlay);
          }
        }
      }
    }
  }

  void _refreshLayout() {
    if (!hasLayout || size.x <= 0) return;
    final double baseTile = size.x / _viewportTiles;
    _tileRenderSize = baseTile * _tileScaleMultiplier;
    final double gridWidth = _tileRenderSize * _viewportTiles;
    final double gridHeight = gridWidth;
    _viewportOrigin = Vector2(
      (size.x - gridWidth) / 2,
      (size.y - gridHeight) / 2,
    );
  }

  void _renderGridLines(ui.Canvas canvas) {
    final double width = _tileRenderSize * _viewportTiles;
    final double height = width;
    for (int i = 0; i <= _viewportTiles; i++) {
      final double dx = _viewportOrigin.x + (i * _tileRenderSize);
      final double dy = _viewportOrigin.y + (i * _tileRenderSize);
      canvas.drawLine(ui.Offset(dx, _viewportOrigin.y),
          ui.Offset(dx, _viewportOrigin.y + height), _gridPaint);
      canvas.drawLine(ui.Offset(_viewportOrigin.x, dy),
          ui.Offset(_viewportOrigin.x + width, dy), _gridPaint);
    }
  }

  void _renderPlayerHighlight(ui.Canvas canvas) {
    final double left = _viewportOrigin.x + (_halfViewport * _tileRenderSize);
    final double top = _viewportOrigin.y + (_halfViewport * _tileRenderSize);
    canvas.drawRect(
        ui.Rect.fromLTWH(left, top, _tileRenderSize, _tileRenderSize),
        _playerPaint);
  }

  void _renderCursorReticle(ui.Canvas canvas) {
    if (_cursorPos == null) return;
    final int col = _cursorPos!.x - _playerPos.x + _halfViewport;
    final int row = _cursorPos!.y - _playerPos.y + _halfViewport;
    if (col < 0 || col >= _viewportTiles || row < 0 || row >= _viewportTiles) {
      return;
    }
    final double left = _viewportOrigin.x + (col * _tileRenderSize);
    final double top = _viewportOrigin.y + (row * _tileRenderSize);
    canvas.drawRect(
        ui.Rect.fromLTWH(left, top, _tileRenderSize, _tileRenderSize),
        _cursorPaint);
    final double centerX = left + _tileRenderSize / 2;
    final double centerY = top + _tileRenderSize / 2;
    final double arm = _tileRenderSize / 4;
    canvas.drawLine(ui.Offset(centerX - arm, centerY),
        ui.Offset(centerX + arm, centerY), _cursorPaint);
    canvas.drawLine(ui.Offset(centerX, centerY - arm),
        ui.Offset(centerX, centerY + arm), _cursorPaint);
  }

  static const Color _rememberedCellOverlay = Color(0x88000000);

  static Color _mfColor(int mf) {
    switch (mf) {
      case 1: return const Color(0xFF4A4A4A);
      case 2: return const Color(0xFF2A1A0A);
      case 5: return const Color(0xFF8B6914);
      case 12:
      case 13: return const Color(0xFF005588);
      case 16: return const Color(0xFF1A3A6A);
      case 17: return const Color(0xFFAA2200);
      case 26: return const Color(0xFF111111);
      default: return const Color(0xFF333333);
    }
  }
}
