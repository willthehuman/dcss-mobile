// Web implementation — dart:io is not available in browsers.
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens a WebSocket on the web platform.
///
/// DCSS webtiles uses application-level raw deflate over the WebSocket.
/// Flutter web's web_socket_channel does NOT decompress permessage-deflate
/// frames transparently — it delivers the raw compressed bytes, which then
/// fail utf8.decode. To avoid this, we append `compression=0` to the URL,
/// which instructs the DCSS server to disable compression for this session,
/// sending plain UTF-8 text frames instead.
///
/// NOTE: Do NOT await channel.ready here. In web_socket_channel ^3.x on web
/// the ready future only completes when the socket *errors*, so awaiting it
/// causes an indefinite hang on a successful connection.
Future<WebSocketChannel> connectPlatform(Uri uri) async {
  // Append compression=0 to disable permessage-deflate on the server side.
  final Uri noCompUri = uri.replace(
    queryParameters: <String, String>{
      ...uri.queryParameters,
      'compression': '0',
    },
  );
  return WebSocketChannel.connect(noCompUri);
}

/// Not used on web.
Object? createInflater() => null;

/// Not used on web — with compression disabled, frames are plain UTF-8 text
/// and arrive as String, not binary. This is only called as a fallback.
String decompressFrame(List<int> frame, Object? inflater) =>
    utf8.decode(frame);
