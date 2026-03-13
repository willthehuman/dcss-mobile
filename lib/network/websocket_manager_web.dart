// Web implementation — dart:io is not available in browsers.
//
// DCSS uses a *stateful* raw-deflate stream across the whole session.
// Each frame has its 4-byte sync-flush trailer (00 00 FF FF) stripped by
// the server. We drive the browser's native DecompressionStream('deflate-raw')
// via dart:js_interop to maintain the shared sliding-window state.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Stateful raw-deflate inflater backed by the browser's DecompressionStream.
class _WebInflater {
  _WebInflater() {
    _ds = web.DecompressionStream('deflate-raw');
    _writer = _ds.writable.getWriter();
    _reader = _ds.readable.getReader();
  }

  late final web.DecompressionStream _ds;
  late final web.WritableStreamDefaultWriter _writer;
  late final web.ReadableStreamDefaultReader _reader;

  /// Decompress one DCSS frame.
  /// Appends the 4-byte sync-flush trailer the server strips, writes to the
  /// DecompressionStream, then drains all available output chunks.
  Future<List<int>> decompress(List<int> frame) async {
    // Append sync-flush trailer: 00 00 FF FF
    final Uint8List input = Uint8List(frame.length + 4);
    input.setRange(0, frame.length, frame);
    input[frame.length + 0] = 0x00;
    input[frame.length + 1] = 0x00;
    input[frame.length + 2] = 0xFF;
    input[frame.length + 3] = 0xFF;

    await _writer.write(input.toJS).toDart;

    // Drain all chunks that are ready without closing the stream.
    final List<int> out = <int>[];
    while (true) {
      // ReadableStreamDefaultReader.read() returns a promise that resolves
      // to {value, done}. We use a non-closing read so the stream stays open.
      final web.ReadableStreamReadResult result =
          await _reader.read().toDart;
      if (result.done) break;
      final JSAny? value = result.value;
      if (value == null) break;
      final Uint8List chunk = (value as JSUint8Array).toDart;
      out.addAll(chunk);
      // After a sync-flush, all pending output is available in one read.
      // Break after the first non-empty chunk to avoid blocking.
      if (chunk.isNotEmpty) break;
    }
    return out;
  }
}

/// Opens a WebSocket on the web platform.
///
/// NOTE: Do NOT await channel.ready here — in web_socket_channel ^3.x on web
/// the ready future only completes when the socket *errors*.
Future<WebSocketChannel> connectPlatform(Uri uri) async {
  return WebSocketChannel.connect(uri);
}

/// Returns a [_WebInflater] as the stateful inflater for the web platform.
Object? createInflater() => _WebInflater();

/// Synchronous stub — not called on web (websocket_manager uses the async path).
String decompressFrame(List<int> frame, Object? inflater) {
  throw UnsupportedError('Use decompressFrameAsync on web.');
}

/// Async decompression for web.
Future<String> decompressFrameAsync(List<int> frame, Object? inflater) async {
  final _WebInflater infl =
      inflater is _WebInflater ? inflater : _WebInflater();
  final List<int> bytes = await infl.decompress(frame);
  return utf8.decode(bytes);
}
