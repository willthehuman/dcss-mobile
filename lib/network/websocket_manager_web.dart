// Web implementation — dart:io is not available in browsers.
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens a WebSocket using the browser's native WebSocket API.
/// The browser transparently handles permessage-deflate negotiation.
Future<WebSocketChannel> connectPlatform(Uri uri) async {
  final WebSocketChannel channel = WebSocketChannel.connect(uri);
  // Await the ready future so connection errors surface immediately.
  await channel.ready;
  return channel;
}

/// Not used on web — browser decompresses frames transparently.
Object? createInflater() => null;

/// Not used on web — binary frames are already decompressed.
String decompressFrame(List<int> frame, Object? inflater) =>
    utf8.decode(frame);
