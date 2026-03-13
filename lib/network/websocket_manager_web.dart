// Web implementation — dart:io is not available in browsers.
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens a WebSocket on the web platform.
///
/// crawl.dcss.io uses application-level raw deflate (same as native).
/// The browser does NOT decompress these frames — they arrive as raw
/// compressed bytes (Uint8List). We decompress them ourselves using
/// dart:convert's ZLibDecoder (compiled to JS via dart2js, no dart:io needed).
///
/// NOTE: Do NOT await channel.ready here. In web_socket_channel ^3.x on web
/// the ready future only completes when the socket *errors*, so awaiting it
/// causes an indefinite hang on a successful connection.
Future<WebSocketChannel> connectPlatform(Uri uri) async {
  return WebSocketChannel.connect(uri);
}

/// Stateful zlib inflater for web — uses dart:convert ZLibDecoder.
/// DCSS uses raw deflate (no zlib header), so we use
/// ZLibDecoder(raw: true) with a persistent context via the Converter API.
Object? createInflater() {
  // Return a ZLibDecoder configured for raw deflate.
  // We re-create a fresh decoder each call since dart:convert's ZLibDecoder
  // is stateless per-call on web (no persistent window like dart:io).
  return const ZLibDecoder(raw: true);
}

/// Decompress a raw-deflate frame using dart:convert ZLibDecoder.
/// Works on both web (dart2js) and native as a fallback.
String decompressFrame(List<int> frame, Object? inflater) {
  try {
    final ZLibDecoder decoder =
        inflater is ZLibDecoder ? inflater : const ZLibDecoder(raw: true);
    final List<int> decompressed = decoder.convert(frame);
    return utf8.decode(decompressed);
  } catch (_) {
    // If raw deflate fails, try standard zlib (with header)
    final List<int> decompressed = const ZLibDecoder().convert(frame);
    return utf8.decode(decompressed);
  }
}
