import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

Future<ui.Image?> loadTileSheetImagePlatform({
  required String? path,
  required List<int>? bytes,
}) async {
  Uint8List? imageBytes;
  if (bytes != null) {
    imageBytes = Uint8List.fromList(bytes);
  } else if (path != null) {
    final File file = File(path);
    if (!await file.exists()) {
      return null;
    }
    imageBytes = await file.readAsBytes();
  }

  if (imageBytes == null || imageBytes.isEmpty) {
    return null;
  }

  final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  return frame.image;
}
