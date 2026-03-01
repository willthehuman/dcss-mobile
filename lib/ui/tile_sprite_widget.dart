import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/tile_index.dart';

class TileSpriteWidget extends StatefulWidget {
  const TileSpriteWidget({
    super.key,
    required this.tileIndex,
    required this.resolver,
    required this.sheetPaths,
    this.size = 32,
  });

  final int tileIndex;
  final TileIndexResolver resolver;
  final Map<String, String> sheetPaths;
  final double size;

  @override
  State<TileSpriteWidget> createState() => _TileSpriteWidgetState();
}

class _TileSpriteWidgetState extends State<TileSpriteWidget> {
  static final Map<String, ui.Image> _imageCache = <String, ui.Image>{};

  ui.Image? _sheetImage;
  TileLocation? _location;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSprite();
  }

  @override
  void didUpdateWidget(TileSpriteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tileIndex != widget.tileIndex) {
      _loadSprite();
    }
  }

  Future<void> _loadSprite() async {
    final TileLocation? loc = widget.resolver.resolve(widget.tileIndex);
    if (loc == null) {
      setState(() {
        _location = null;
        _sheetImage = null;
      });
      return;
    }

    _location = loc;

    final ui.Image? cached = _imageCache[loc.sheet];
    if (cached != null) {
      setState(() => _sheetImage = cached);
      return;
    }

    if (_loading) {
      return;
    }
    _loading = true;

    final String? path = widget.sheetPaths[loc.sheet];
    if (path == null) {
      _loading = false;
      return;
    }

    try {
      final File file = File(path);
      if (!await file.exists()) {
        _loading = false;
        return;
      }
      final Uint8List bytes = await file.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      _imageCache[loc.sheet] = frame.image;
      if (mounted) {
        setState(() => _sheetImage = frame.image);
      }
    } catch (_) {
      // Skip on error.
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
