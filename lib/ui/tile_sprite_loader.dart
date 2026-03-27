import 'dart:ui' as ui;

import 'tile_sprite_loader_io.dart'
    if (dart.library.html) 'tile_sprite_loader_web.dart';

Future<ui.Image?> loadTileSheetImage({
  required String? path,
  required List<int>? bytes,
}) {
  return loadTileSheetImagePlatform(path: path, bytes: bytes);
}
