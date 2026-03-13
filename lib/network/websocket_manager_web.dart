// Web implementation — dart:io is not available in browsers.
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens a WebSocket using the browser's native WebSocket API.
/// The browser transparently handles permessage-deflate negotiation.
///
/// NOTE: Do NOT await channel.ready here. In web_socket_channel ^3.x on web
/// the ready future only completes when the socket *errors*, so awaiting it
/// causes an indefinite hang on a successful connection. Connection errors are
/// surfaced via the stream's onError / onDone callbacks instead.
Future<WebSocketChannel> connectPlatform(Uri uri) async {
  return WebSocketChannel.connect(uri);
}

/// Not used on web — browser decompresses frames transparently.
Object? createInflater() => null;

/// Not used on web — binary frames are already decompressed.
String decompressFrame(List<int> frame, Object? inflater) =>
    utf8.decode(frame);
