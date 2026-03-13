// Web implementation — dart:io is not available in browsers.
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens a WebSocket on the web platform.
///
/// crawl.dcss.io sends application-level raw-deflate compressed frames
/// (same as the native protocol). The browser does NOT decompress these
/// automatically — we must do it ourselves using the pure-Dart `archive`
/// package (works on web via dart2js, no dart:io required).
///
/// NOTE: Do NOT await channel.ready here. In web_socket_channel ^3.x on web
/// the ready future only completes when the socket *errors*, so awaiting it
/// causes an indefinite hang on a successful connection.
Future<WebSocketChannel> connectPlatform(Uri uri) async {
  return WebSocketChannel.connect(uri);
}

/// Returns an `archive` ZLibDecoder as the inflater object for web.
Object? createInflater() => ZLibDecoder();

/// Decompress a raw-deflate frame using the pure-Dart `archive` package.
/// `archive`'s ZLibDecoder handles both raw deflate and zlib-wrapped deflate.
String decompressFrame(List<int> frame, Object? inflater) {
  final ZLibDecoder decoder =
      inflater is ZLibDecoder ? inflater : ZLibDecoder();
  final List<int> decompressed = decoder.decodeBytes(frame);
  return utf8.decode(decompressed);
}
