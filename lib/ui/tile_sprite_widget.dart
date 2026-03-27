import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/tile_index.dart';
import 'tile_sprite_loader.dart';

class TileSpriteWidget extends StatefulWidget {
  const TileSpriteWidget({
    super.key,
    required this.tileIndex,
    required this.resolver,
    required this.sheetPaths,
    required this.sheetBytes,
    this.size = 32,
  });

  final int tileIndex;
  final TileIndexResolver resolver;
  final Map<String, String> sheetPaths;
  final Map<String, List<int>> sheetBytes;
  final double size;

  @override
  State<TileSpriteWidget> createState() => _TileSpriteWidgetState();
}

class _TileSpriteWidgetState extends State<TileSpriteWidget> {
  static final Map<String, ui.Image> _imageCache = <String, ui.Image>{};

  ui.Image? _sheetImage;
  TileLocation? _location;
  bool _loading = false;
  String? _cacheKey;

  @override
  void initState() {
    super.initState();
    _loadSprite();
  }

  @override
  void didUpdateWidget(TileSpriteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tileIndex != widget.tileIndex ||
        !_sameSheetSourceMaps(oldWidget.sheetPaths, widget.sheetPaths) ||
        !_sameSheetBytesMaps(oldWidget.sheetBytes, widget.sheetBytes)) {
      _loadSprite();
    }
  }

  Future<void> _loadSprite() async {
    final TileLocation? loc = widget.resolver.resolve(widget.tileIndex);
    if (loc == null) {
      setState(() {
        _location = null;
        _sheetImage = null;
        _cacheKey = null;
      });
      return;
    }

    _location = loc;
    final String cacheKey = _sheetCacheKey(loc.sheet);
    if (_cacheKey != cacheKey) {
      _sheetImage = null;
    }
    _cacheKey = cacheKey;

    final ui.Image? cached = _imageCache[cacheKey];
    if (cached != null) {
      setState(() => _sheetImage = cached);
      return;
    }

    if (_loading) {
      return;
    }
    _loading = true;

    final String? path = widget.sheetPaths[loc.sheet];
    final List<int>? bytes = widget.sheetBytes[loc.sheet];
    if (path == null && bytes == null) {
      if (mounted) {
        setState(() => _sheetImage = null);
      }
      _loading = false;
      return;
    }

    try {
      final ui.Image? image = await loadTileSheetImage(path: path, bytes: bytes);
      if (image == null) {
        if (mounted) {
          setState(() => _sheetImage = null);
        }
        _loading = false;
        return;
      }
      _imageCache[cacheKey] = image;
      if (mounted && _cacheKey == cacheKey) {
        setState(() => _sheetImage = image);
      }
    } catch (error) {
      debugPrint(
        '[TileSpriteWidget] Failed to load sheet ${loc.sheet} for tile ${widget.tileIndex}: $error',
      );
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sheetImage == null || _location == null) {
      return SizedBox.square(dimension: widget.size);
    }

    return CustomPaint(
      size: Size.square(widget.size),
      painter: _SpritePainter(
        image: _sheetImage!,
        location: _location!,
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  const _SpritePainter({required this.image, required this.location});

  final ui.Image image;
  final TileLocation location;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect src = Rect.fromLTWH(
      location.x.toDouble(),
      location.y.toDouble(),
      location.w.toDouble(),
      location.h.toDouble(),
    );
    final Rect dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(_SpritePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.location.x != location.x ||
        oldDelegate.location.y != location.y ||
        oldDelegate.location.sheet != location.sheet;
  }
}

bool _sameSheetSourceMaps(
  Map<String, String> left,
  Map<String, String> right,
) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (final MapEntry<String, String> entry in left.entries) {
    if (right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

bool _sameSheetBytesMaps(
  Map<String, List<int>> left,
  Map<String, List<int>> right,
) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (final MapEntry<String, List<int>> entry in left.entries) {
    final List<int>? other = right[entry.key];
    if (!identical(entry.value, other)) {
      return false;
    }
  }
  return true;
}

String _sheetSourceFingerprint(String sheetName, TileSpriteWidget widget) {
  final String? path = widget.sheetPaths[sheetName];
  if (path != null) {
    return 'path:$path';
  }

  final List<int>? bytes = widget.sheetBytes[sheetName];
  if (bytes != null) {
    return 'bytes:${identityHashCode(bytes)}:${bytes.length}';
  }

  return 'missing';
}

extension on _TileSpriteWidgetState {
  String _sheetCacheKey(String sheetName) {
    return '$sheetName:${_sheetSourceFingerprint(sheetName, widget)}';
  }
}
