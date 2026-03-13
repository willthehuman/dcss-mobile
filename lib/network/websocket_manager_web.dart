// Web implementation — dart:io is not available in browsers.
//
// DCSS uses a *stateful* raw-deflate stream across the whole session.
// Each frame has its 4-byte sync-flush trailer (00 00 FF FF) stripped by
// the server. We drive the browser's native DecompressionStream('deflate-raw')
// via dart:js_interop using raw JSObject calls, which avoids the incomplete
// typed bindings in package:web ^1.1.0 (getReader returns JSObject, not the
// typed ReadableStreamDefaultReader).
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

// ---------------------------------------------------------------------------
// Minimal JS interop declarations for the Streams API.
// We only declare what we need so we aren't blocked by package:web gaps.
// ---------------------------------------------------------------------------

@JS('DecompressionStream')
external JSObject _newDecompressionStream(String format);

extension _JSObjectCall on JSObject {
  external JSObject callMethod(String name);
  external JSObject callMethodWith1(String name, JSAny? arg);
  external JSAny? get(String key);
}

// Workaround: dart:js_interop doesn't expose callMethod directly,
// so we use JS eval helpers via extension types.
extension type _JSObj(JSObject _) implements JSObject {}

// Helper: call obj.method() with 0 args → JSObject
@JS()
external JSObject _jsCall0(JSObject obj, String method);

@JS()
external JSObject _jsCall1(JSObject obj, String method, JSAny arg);

@JS()
external JSAny? _jsProp(JSObject obj, String prop);

@JS()
external JSPromise<JSObject> _jsCallPromise0(JSObject obj, String method);

@JS()
external JSPromise<JSObject> _jsCallPromise1(
    JSObject obj, String method, JSAny arg);

// Inject the tiny JS helpers once at startup.
@JS('eval')
external void _jsEval(String code);

bool _helpersInjected = false;
void _ensureHelpers() {
  if (_helpersInjected) return;
  _helpersInjected = true;
  _jsEval('''
    self._jsCall0 = (o,m) => o[m]();
    self._jsCall1 = (o,m,a) => o[m](a);
    self._jsProp  = (o,p) => o[p];
    self._jsCallPromise0 = (o,m) => o[m]();
    self._jsCallPromise1 = (o,m,a) => o[m](a);
  ''');
}

// ---------------------------------------------------------------------------

/// Stateful raw-deflate inflater backed by the browser's DecompressionStream.
class _WebInflater {
  _WebInflater() {
    _ensureHelpers();
    final JSObject ds = _newDecompressionStream('deflate-raw');
    final JSObject writable = _jsProp(ds, 'writable')! as JSObject;
    final JSObject readable = _jsProp(ds, 'readable')! as JSObject;
    _writer = _jsCall0(writable, 'getWriter');
    _reader = _jsCall0(readable, 'getReader');
  }

  late final JSObject _writer;
  late final JSObject _reader;

  Future<List<int>> decompress(List<int> frame) async {
    // Append the 4-byte sync-flush trailer the DCSS server strips.
    final Uint8List input = Uint8List(frame.length + 4);
    input.setRange(0, frame.length, frame);
    input[frame.length + 0] = 0x00;
    input[frame.length + 1] = 0x00;
    input[frame.length + 2] = 0xFF;
    input[frame.length + 3] = 0xFF;

    // Write to the DecompressionStream writer.
    await _jsCallPromise1(_writer, 'write', input.toJS).toDart;

    // Read one chunk — a sync-flush guarantees all output is in one read.
    final JSObject result =
        await _jsCallPromise0(_reader, 'read').toDart;

    final JSAny? value = _jsProp(result, 'value');
    if (value == null) return <int>[];
    final Uint8List chunk = (value as JSUint8Array).toDart;
    return chunk;
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

/// Synchronous stub — not used on web.
String decompressFrame(List<int> frame, Object? inflater) {
  throw UnsupportedError('Use decompressFrameAsync on web.');
}

/// Async decompression for web using the stateful DecompressionStream inflater.
Future<String> decompressFrameAsync(List<int> frame, Object? inflater) async {
  final _WebInflater infl =
      inflater is _WebInflater ? inflater : _WebInflater();
  final List<int> bytes = await infl.decompress(frame);
  return utf8.decode(bytes);
}
