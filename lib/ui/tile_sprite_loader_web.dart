import 'dart:typed_data';
import 'dart:ui' as ui;

Future<ui.Image?> loadTileSheetImagePlatform({
  required String? path,
  required List<int>? bytes,
}) async {
  if (bytes == null || bytes.isEmpty) {
    return null;
  }

  final ui.Codec codec =
      await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  final ui.FrameInfo frame = await codec.getNextFrame();
  return frame.image;
}
