// Web stub — file loading is not available in browsers.
// On web, TileScene.setTileAssets uses sheetBytes directly (kIsWeb branch).
import 'dart:ui' as ui;

Future<void> loadSheetImagesFromFiles(
  Map<String, String> sheetPaths,
  Map<String, ui.Image> out,
) async {
  // No-op on web: images are loaded from in-memory bytes instead.
}
