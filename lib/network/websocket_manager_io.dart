// Native (dart:io) implementation — used on Android and iOS.
import 'dart:convert';
import 'dart:io' show WebSocket, CompressionOptions, RawZLibFilter;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens a native WebSocket with permessage-deflate disabled.
/// DCSS uses application-level raw deflate, so we handle it ourselves.
Future<WebSocketChannel> connectPlatform(Uri uri) async {
  final WebSocket rawSocket = await WebSocket.connect(
    uri.toString(),
    compression: CompressionOptions.compressionOff,
  ).timeout(
    const Duration(seconds: 15),
    onTimeout: () => throw Exception('Connection timed out.'),
  );
  return IOWebSocketChannel(rawSocket);
}

/// Creates a stateful raw-deflate inflater for application-level decompression.
RawZLibFilter createInflater() =>
    RawZLibFilter.inflateFilter(raw: true, windowBits: 15);

/// Decompresses a single DCSS binary frame using the stateful [inflater].
/// DCSS strips the 4-byte sync-flush trailer; we add it back before inflating.
String decompressFrame(List<int> frame, Object? inflater) {
  final RawZLibFilter zlib = inflater! as RawZLibFilter;
  final List<int> withTrailer = [...frame, 0, 0, 255, 255];
  zlib.process(withTrailer, 0, withTrailer.length);
  final List<int> decompressed = <int>[];
  List<int>? chunk;
  while ((chunk = zlib.processed(flush: false)) != null) {
    decompressed.addAll(chunk!);
  }
  return utf8.decode(decompressed);
}

/// Not used on native — stub to satisfy conditional import.
Future<String> decompressFrameAsync(List<int> frame, Object? inflater) async =>
    decompressFrame(frame, inflater);
