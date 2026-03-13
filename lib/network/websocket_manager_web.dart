// Web implementation — dart:io is not available in browsers.
//
// DCSS uses a *stateful* raw-deflate stream across the whole session.
// Each frame has its 4-byte sync-flush trailer (00 00 FF FF) stripped by
// the server. We drive the browser's native DecompressionStream('deflate-raw')
// via dart:js_interop.
//
// All JS helpers are registered on window in web/dcss_helpers.js,
// which is loaded as a plain <script> before flutter_bootstrap.js.
// This guarantees every @JS() extern resolves correctly in dart2js/dart2wasm.
//
// IMPORTANT: Do NOT await writer.write() before calling reader.read().
// DecompressionStream is a TransformStream — writer.write() only resolves
// once the readable side is consumed. The correct pattern:
//   1. Fire write() without awaiting.
//   2. Await read() — this pulls data through and resolves both promises.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

// All functions below are defined in web/dcss_helpers.js.
@JS('_newDecompressionStream')
external JSObject _jsNewDecompressionStream(String format);

@JS('_jsProp')
external JSAny? _jsProp(JSObject obj, String prop);

@JS('_jsCall0')
external JSObject _jsCall0(JSObject obj, String method);

@JS('_jsCall1Void')
external void _jsCall1Void(JSObject obj, String method, JSAny arg);

@JS('_jsCallPromise0')
external JSPromise<JSObject> _jsCallPromise0(JSObject obj, String method);

/// Stateful raw-deflate inflater backed by the browser's DecompressionStream.
class _WebInflater {
  _WebInflater() {
    final JSObject ds = _jsNewDecompressionStream('deflate-raw');
    _writer = _jsCall0(_jsProp(ds, 'writable')! as JSObject, 'getWriter');
    _reader = _jsCall0(_jsProp(ds, 'readable')! as JSObject, 'getReader');
  }

  late final JSObject _writer;
  late final JSObject _reader;

  Future<List<int>> decompress(List<int> frame) async {
    // Re-attach the 4-byte sync-flush trailer the DCSS server strips.
    final Uint8List input = Uint8List(frame.length + 4);
    input.setRange(0, frame.length, frame);
    input[frame.length + 0] = 0x00;
    input[frame.length + 1] = 0x00;
    input[frame.length + 2] = 0xFF;
    input[frame.length + 3] = 0xFF;

    // Fire write WITHOUT awaiting — awaiting before read() deadlocks.
    _jsCall1Void(_writer, 'write', input.toJS);

    // Await read() — pulls data through the transform.
    // Sync-flush guarantees all output is in one chunk.
    final JSObject result = await _jsCallPromise0(_reader, 'read').toDart;
    final JSAny? value = _jsProp(result, 'value');
    if (value == null) return <int>[];
    return (value as JSUint8Array).toDart;
  }
}

Future<WebSocketChannel> connectPlatform(Uri uri) async =>
    WebSocketChannel.connect(uri);

Object? createInflater() => _WebInflater();

String decompressFrame(List<int> frame, Object? inflater) =>
    throw UnsupportedError('Use decompressFrameAsync on web.');

Future<String> decompressFrameAsync(List<int> frame, Object? inflater) async {
  final _WebInflater infl =
      inflater is _WebInflater ? inflater : _WebInflater();
  return utf8.decode(await infl.decompress(frame));
}
