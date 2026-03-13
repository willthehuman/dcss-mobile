// Native (dart:io) image loading from cached files.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

Future<void> loadSheetImagesFromFiles(
  Map<String, String> sheetPaths,
  Map<String, ui.Image> out,
) async {
  for (final MapEntry<String, String> entry in sheetPaths.entries) {
    final File file = File(entry.value);
    if (!await file.exists()) continue;
    try {
      final Uint8List bytes = await file.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      out[entry.key] = frame.image;
    } catch (e) {
      debugPrint('[TileScene] failed to load ${entry.key}: $e');
    }
  }
}
