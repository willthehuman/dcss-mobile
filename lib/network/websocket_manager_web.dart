// Web implementation — dart:io is not available in browsers.
//
// DCSS uses a *stateful* raw-deflate stream across the whole session.
// Each frame has its 4-byte sync-flush trailer (00 00 FF FF) stripped by
// the server. We drive the browser's native DecompressionStream('deflate-raw')
// via dart:js_interop raw JSObject calls.
//
// IMPORTANT: Do NOT await writer.write() before calling reader.read().
// DecompressionStream is a TransformStream — writer.write() only resolves
// once the readable side is consumed. Awaiting it before reading causes an
// instant deadlock. The correct pattern is:
//   1. Fire write() without awaiting.
//   2. Await read() — this pulls the data through and resolves both promises.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

@JS('DecompressionStream')
external JSObject _newDecompressionStream(String format);

@JS()
external JSAny? _jsProp(JSObject obj, String prop);

@JS()
external JSObject _jsCall0(JSObject obj, String method);

@JS()
external void _jsCall1Void(JSObject obj, String method, JSAny arg);

@JS()
external JSPromise<JSObject> _jsCallPromise0(JSObject obj, String method);

@JS('eval')
external void _jsEval(String code);

bool _helpersInjected = false;
void _ensureHelpers() {
  if (_helpersInjected) return;
  _helpersInjected = true;
  _jsEval('''
    self._jsProp         = (o,p)   => o[p];
    self._jsCall0        = (o,m)   => o[m]();
    self._jsCall1Void    = (o,m,a) => { o[m](a); };
    self._jsCallPromise0 = (o,m)   => o[m]();
  ''');
}

/// Stateful raw-deflate inflater backed by the browser's DecompressionStream.
class _WebInflater {
  _WebInflater() {
    _ensureHelpers();
    final JSObject ds = _newDecompressionStream('deflate-raw');
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

    // Fire write WITHOUT awaiting — awaiting before read() deadlocks because
    // write() only resolves once the readable side is consumed.
    _jsCall1Void(_writer, 'write', input.toJS);

    // Await read() — this pulls data through the transform and resolves both.
    // A sync-flush guarantees all decompressed output is in one chunk.
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
