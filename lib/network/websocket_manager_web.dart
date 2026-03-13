// Web implementation — dart:io is not available in browsers.
//
// DCSS uses a *stateful* raw-deflate stream: frames are continuations of a
// single deflate context (shared sliding window). Each frame has its 4-byte
// sync-flush trailer (00 00 FF FF) stripped by the server. We must:
//   1. Append the trailer back before feeding each chunk.
//   2. Keep the same inflater context alive across frames.
//
// dart:io's RawZLibFilter does this on native. On web we drive the browser's
// native DecompressionStream('deflate-raw') via dart:js_interop + dart:js.
import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Thin wrapper around a browser DecompressionStream('deflate-raw').
/// We push chunks in synchronously via the JS WritableStream writer
/// and drain the ReadableStream reader after each write.
class _WebInflater {
  _WebInflater() {
    final js.JsObject ds =
        js.JsObject(js.context['DecompressionStream'] as js.JsFunction,
            <String>['deflate-raw']);
    _writer = js.JsObject.fromBrowserObject(
        (ds['writable'] as js.JsObject).callMethod('getWriter') as Object);
    _reader = js.JsObject.fromBrowserObject(
        (ds['readable'] as js.JsObject).callMethod('getReader') as Object);
  }

  late final js.JsObject _writer;
  late final js.JsObject _reader;

  /// Decompress [frame] (raw deflate chunk, sync-flush trailer stripped).
  /// Returns the decompressed bytes synchronously by draining the reader.
  Future<List<int>> decompress(List<int> frame) async {
    // Re-attach the 4-byte sync-flush trailer the DCSS server strips.
    final Uint8List withTrailer = Uint8List(frame.length + 4);
    withTrailer.setRange(0, frame.length, frame);
    withTrailer[frame.length] = 0x00;
    withTrailer[frame.length + 1] = 0x00;
    withTrailer[frame.length + 2] = 0xFF;
    withTrailer[frame.length + 3] = 0xFF;

    // Write the chunk to the DecompressionStream.
    await _promiseToFuture(
        _writer.callMethod('write', <Object>[withTrailer]) as Object);

    // Drain all available chunks from the reader.
    final List<int> out = <int>[];
    while (true) {
      final js.JsObject result = js.JsObject.fromBrowserObject(
          await _promiseToFuture(
              _reader.callMethod('read') as Object));
      final bool done = result['done'] as bool? ?? false;
      if (done) break;
      final Object? value = result['value'];
      if (value != null) {
        final js.JsObject arr = js.JsObject.fromBrowserObject(value);
        final int len = arr['length'] as int? ?? 0;
        for (int i = 0; i < len; i++) {
          out.add(arr[i] as int);
        }
      }
      // If not done but value was empty, we've drained what's available.
      if (!done && (value == null || (js.JsObject.fromBrowserObject(value)['length'] as int? ?? 0) == 0)) break;
    }
    return out;
  }
}

Future<T> _promiseToFuture<T>(Object jsPromise) {
  final Completer<T> completer = Completer<T>();
  final js.JsObject promise = js.JsObject.fromBrowserObject(jsPromise);
  promise.callMethod('then', <Object>[
    js.allowInterop((dynamic value) => completer.complete(value as T)),
  ]);
  promise.callMethod('catch', <Object>[
    js.allowInterop((dynamic error) => completer.completeError(error as Object)),
  ]);
  return completer.future;
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

/// Decompresses a single DCSS binary frame using the stateful [inflater].
/// Returns the decompressed UTF-8 string.
/// NOTE: this is async on web — caller must handle it.
/// On web, [inflater] is a [_WebInflater]; this function returns a Future<String>
/// disguised as String via a workaround — see websocket_manager.dart handling.
String decompressFrame(List<int> frame, Object? inflater) {
  // Synchronous fallback — should not be reached on web since
  // websocket_manager.dart calls decompressFrameAsync on web.
  throw UnsupportedError('Use decompressFrameAsync on web.');
}

/// Async version of decompressFrame for web use.
Future<String> decompressFrameAsync(List<int> frame, Object? inflater) async {
  final _WebInflater infl =
      inflater is _WebInflater ? inflater : _WebInflater();
  final List<int> bytes = await infl.decompress(frame);
  return utf8.decode(bytes);
}
