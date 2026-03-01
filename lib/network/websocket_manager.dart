import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io' show WebSocket, CompressionOptions, RawZLibFilter;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dcss_protocol.dart';

enum WebsocketConnectionStatus {
  disconnected,
  connecting,
  authenticating,
  connected,
  reconnecting,
  error,
}

class WebsocketState {
  const WebsocketState({
    this.status = WebsocketConnectionStatus.disconnected,
    this.serverUrl = '',
    this.username = '',
    this.errorMessage,
    this.reconnectAttempt = 0,
    this.isLoggedIn = false,
  });

  final WebsocketConnectionStatus status;
  final String serverUrl;
  final String username;
  final String? errorMessage;
  final int reconnectAttempt;
  final bool isLoggedIn;

  bool get isConnected =>
      status == WebsocketConnectionStatus.connected && isLoggedIn;

  WebsocketState copyWith({
    WebsocketConnectionStatus? status,
    String? serverUrl,
    String? username,
    String? errorMessage,
    bool clearError = false,
    int? reconnectAttempt,
    bool? isLoggedIn,
  }) {
    return WebsocketState(
      status: status ?? this.status,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }
}

class _Credentials {
  const _Credentials({
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.gameId,
  });

  final String serverUrl;
  final String username;
  final String password;
  final String gameId;
}

final websocketProvider =
    StateNotifierProvider<WebsocketManager, WebsocketState>(
  (Ref ref) => WebsocketManager(),
);

class WebsocketManager extends StateNotifier<WebsocketState> {
  WebsocketManager() : super(const WebsocketState());

  static const int _maxReconnectAttempts = 4;

  final StreamController<DcssMessage> _messageController =
      StreamController<DcssMessage>.broadcast();

  Stream<DcssMessage> get messages => _messageController.stream;

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  Timer? _reconnectTimer;
  _Credentials? _credentials;
  int _nextBackoffSeconds = 1;
  bool _manualDisconnect = false;
  late RawZLibFilter _inflater;
  bool _playRequestSent = false;

  Future<void> connect({
    required String serverUrl,
    required String username,
    required String password,
    String gameId = 'dcss-web-trunk',
  }) async {
    _credentials = _Credentials(
      serverUrl: serverUrl.trim(),
      username: username.trim(),
      password: password,
      gameId: gameId,
    );
    _manualDisconnect = false;
    _nextBackoffSeconds = 1;
    _reconnectTimer?.cancel();
    _playRequestSent = false;

    state = state.copyWith(
      status: WebsocketConnectionStatus.connecting,
      serverUrl: serverUrl.trim(),
      username: username.trim(),
      reconnectAttempt: 0,
      isLoggedIn: false,
      clearError: true,
    );

    await _openSocket(isReconnect: false);
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    await _closeChannel();
    state = state.copyWith(
      status: WebsocketConnectionStatus.disconnected,
      reconnectAttempt: 0,
      isLoggedIn: false,
      clearError: true,
    );
  }

  void sendOutgoing(DcssOutgoingMessage message) {
    final IOWebSocketChannel? activeChannel = _channel;
    if (activeChannel == null) {
      return;
    }
    activeChannel.sink.add(jsonEncode(message.toJson()));
  }

  void sendKeyCode(int keycode) {
    sendOutgoing(KeyPressRequest(keycode: keycode));
  }

  void sendInput(String text) {
    sendOutgoing(InputRequest(text: text));
  }

  void sendTextInput(String text) {
    sendOutgoing(TextInputRequest(text: text));
  }

  void sendTileClick({required int x, required int y, int button = 1}) {
    sendOutgoing(TileClickRequest(x: x, y: y, button: button));
  }

  Future<void> _openSocket({required bool isReconnect}) async {
    final _Credentials? credentials = _credentials;
    if (credentials == null) {
      return;
    }

    await _closeChannel();

    _playRequestSent = false;

    state = state.copyWith(
      status: isReconnect
          ? WebsocketConnectionStatus.reconnecting
          : WebsocketConnectionStatus.connecting,
      isLoggedIn: false,
      clearError: true,
    );

    try {
      final Uri uri = Uri.parse(credentials.serverUrl);

      // Use dart:io WebSocket directly to disable permessage-deflate compression,
      // which the DCSS Tornado server negotiates by default but Flutter's
      // IOWebSocketChannel cannot transparently decompress.
      final WebSocket rawSocket = await WebSocket.connect(
        uri.toString(),
        compression: CompressionOptions.compressionOff,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Connection timed out.'),
      );

      _channel = IOWebSocketChannel(rawSocket);

      // New stateful raw-deflate decompressor for each connection.
      // DCSS uses application-level deflate (NOT permessage-deflate), so
      // the same decompressor instance MUST be reused across all frames.
      _inflater = RawZLibFilter.inflateFilter(raw: true, windowBits: 15);

      state = state.copyWith(
        status: WebsocketConnectionStatus.authenticating,
        clearError: true,
      );

      _channelSubscription = _channel!.stream.listen(
        _onSocketData,
        onError: _onSocketError,
        onDone: _onSocketDone,
        cancelOnError: false,
      );
    } catch (error) {
      _scheduleReconnect(error.toString());
    }
  }

  Future<void> _closeChannel() async {
    await _channelSubscription?.cancel();
    _channelSubscription = null;

    try {
      await _channel?.sink.close();
    } catch (_) {
      // Ignore close errors.
    }
    _channel = null;
  }

  void _onSocketData(dynamic rawEvent) {
    try {
      final String rawText;
      if (rawEvent is String) {
        rawText = rawEvent;
      } else if (rawEvent is List<int>) {
        // DCSS strips the 4-byte deflate sync-flush trailer from each frame.
        // Add it back, then feed into the stateful decompressor.
        final List<int> withTrailer = [...rawEvent, 0, 0, 255, 255];
        _inflater.process(withTrailer, 0, withTrailer.length);
        final List<int> decompressed = <int>[];
        List<int>? chunk;
        while ((chunk = _inflater.processed(flush: false)) != null) {
          decompressed.addAll(chunk!);
        }
        rawText = utf8.decode(decompressed);
      } else {
        rawText = rawEvent.toString();
      }

      final Map<String, dynamic> payload = parseJsonMap(rawText);

      // DCSS always batches messages: {"msgs": [{"msg": "..."}, ...]}
      final dynamic batch = payload['msgs'];
      if (batch is List) {
        for (final dynamic item in batch) {
          if (item is Map) {
            _handleMessage(Map<String, dynamic>.from(
              item.map((dynamic k, dynamic v) =>
                  MapEntry<String, dynamic>(k.toString(), v)),
            ));
          }
        }
      } else {
        _handleMessage(payload); // fallback for plain single-message frames
      }
    } catch (error) {
      _messageController.add(UnknownMessage(
        rawType: 'parse_error',
        payload: <String, dynamic>{'error': error.toString()},
      ));
    }
  }

  void _handleMessage(Map<String, dynamic> json) {
    final DcssMessage message = DcssMessageFactory.fromJson(json);
    _messageController.add(message);

    debugPrint('[DCSS] msg: ${message.type}');

    if (message is PingMessage) {
      sendOutgoing(const PongRequest());
      return;
    }
    if (message is LoginSuccessMessage) {
      _nextBackoffSeconds = 1;
      state = state.copyWith(
        status: WebsocketConnectionStatus.connected,
        isLoggedIn: true,
        reconnectAttempt: 0,
        clearError: true,
      );
      return;
    }

    if (message is SetGameLinksMessage) {
      if (_credentials != null && state.isLoggedIn && !_playRequestSent) {
        _playRequestSent = true;
        final String gameId = message.gameIds.isNotEmpty
            ? message.gameIds.first
            : _credentials!.gameId;
        debugPrint('[DCSS] set_game_links → playing: $gameId');
        sendOutgoing(PlayRequest(gameId: gameId));
      }
      return;
    }
    if (message is GoLobbyMessage) {
      debugPrint('[DCSS] go_lobby received — play failed or game ended');
      state = state.copyWith(
        status: WebsocketConnectionStatus.error,
        errorMessage: 'Server sent go_lobby — game ended or invalid game ID.',
        isLoggedIn: false,
      );
      return;
    }
    if (message is LobbyCompleteMessage) {
      if (_credentials != null && !state.isLoggedIn) {
        debugPrint('[DCSS] lobby_complete → sending LoginRequest');
        sendOutgoing(LoginRequest(
          username: _credentials!.username,
          password: _credentials!.password,
        ));
      }
      // Second lobby_complete (post-login): PlayRequest already sent above.
      return;
    }

    if (message is LoginFailMessage) {
      _manualDisconnect = true;
      _reconnectTimer?.cancel();
      state = state.copyWith(
        status: WebsocketConnectionStatus.error,
        errorMessage: message.reason,
        isLoggedIn: false,
      );
      unawaited(_closeChannel());
    }

    if (message is InputModeMessage) {
      // mode 1 = normal game input — send a no-op to unblock the server
      if (message.mode == 1) {
        sendOutgoing(const PongRequest()); // or a key(0) to ACK
      }
      return;
    }
  }

  void _onSocketError(Object error) {
    _scheduleReconnect(error.toString());
  }

  void _onSocketDone() {
    _scheduleReconnect('Socket connection closed.');
  }

  void _scheduleReconnect(String reason) {
    if (_manualDisconnect || _credentials == null) {
      if (state.status == WebsocketConnectionStatus.error) {
        return;
      }
      state = state.copyWith(
        status: WebsocketConnectionStatus.disconnected,
        errorMessage: reason,
        reconnectAttempt: 0,
        isLoggedIn: false,
      );
      return;
    }

    final int attempt = state.reconnectAttempt + 1;

    // Give up after max attempts and surface an error.
    if (attempt > _maxReconnectAttempts) {
      state = state.copyWith(
        status: WebsocketConnectionStatus.error,
        errorMessage:
            'Unable to connect after $_maxReconnectAttempts attempts: $reason',
        reconnectAttempt: attempt,
        isLoggedIn: false,
      );
      return;
    }

    final int delaySeconds = _nextBackoffSeconds;
    _nextBackoffSeconds = min(_nextBackoffSeconds * 2, 30);

    state = state.copyWith(
      status: WebsocketConnectionStatus.reconnecting,
      errorMessage: reason,
      reconnectAttempt: attempt,
      isLoggedIn: false,
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _openSocket(isReconnect: true);
    });
  }

  @override
  void dispose() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    unawaited(_closeChannel());
    _messageController.close();
    super.dispose();
  }
}
