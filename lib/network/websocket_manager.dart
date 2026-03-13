import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// dart:io imports are only valid on native platforms.
import 'websocket_manager_io.dart'
    if (dart.library.html) 'websocket_manager_web.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../debug/socket_log.dart';
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

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  Timer? _reconnectTimer;
  _Credentials? _credentials;
  int _nextBackoffSeconds = 1;
  bool _manualDisconnect = false;
  Object? _inflater;
  bool _playRequestSent = false;

  SocketLog? _socketLog;
  void attachLog(SocketLog log) => _socketLog = log;
  void detachLog() => _socketLog = null;

  void _log(String msg) {
    debugPrint('[WS] $msg');
    _socketLog?.add(msg);
  }

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
    final WebSocketChannel? activeChannel = _channel;
    if (activeChannel == null) return;
    activeChannel.sink.add(jsonEncode(message.toJson()));
  }

  void sendKeyCode(int keycode) => sendOutgoing(KeyPressRequest(keycode: keycode));
  void sendInput(String text) => sendOutgoing(InputRequest(text: text));
  void sendTextInput(String text) => sendOutgoing(TextInputRequest(text: text));
  void sendTileClick({required int x, required int y, int button = 1}) =>
      sendOutgoing(TileClickRequest(x: x, y: y, button: button));

  Future<void> _openSocket({required bool isReconnect}) async {
    final _Credentials? credentials = _credentials;
    if (credentials == null) return;

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
      _log('Connecting to $uri (isWeb=$kIsWeb)');

      final WebSocketChannel channel = await connectPlatform(uri);
      _channel = channel;
      _log('connectPlatform returned — attaching stream listener');

      // Always initialise the inflater via the platform stub.
      // On native: dart:io RawZLibFilter; on web: dart:convert ZLibDecoder.
      _inflater = createInflater();

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
      _log('Stream listener attached — waiting for frames…');
    } catch (error) {
      _log('ERROR in _openSocket: $error');
      _scheduleReconnect(error.toString());
    }
  }

  Future<void> _closeChannel() async {
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _onSocketData(dynamic rawEvent) {
    // Log the raw frame type BEFORE any processing so we always see it.
    final String frameType = rawEvent.runtimeType.toString();
    final int frameLen = rawEvent is List
        ? rawEvent.length
        : rawEvent is String
            ? rawEvent.length
            : -1;
    _log('FRAME type=$frameType len=$frameLen');

    try {
      final String rawText;

      if (rawEvent is String) {
        rawText = rawEvent;
      } else if (rawEvent is Uint8List || rawEvent is List<int>) {
        // Binary frame — always decompress (works on both native and web).
        final List<int> bytes =
            rawEvent is Uint8List ? rawEvent : rawEvent as List<int>;
        rawText = decompressFrame(bytes, _inflater);
      } else {
        rawText = rawEvent.toString();
      }

      final String preview =
          rawText.length > 120 ? '${rawText.substring(0, 120)}…' : rawText;
      _log('DECODED | $preview');

      final Map<String, dynamic> payload = parseJsonMap(rawText);

      final dynamic batch = payload['msgs'];
      if (batch is List) {
        _log('  batch of ${batch.length} msgs');
        for (final dynamic item in batch) {
          if (item is Map) {
            _handleMessage(Map<String, dynamic>.from(
              item.map((dynamic k, dynamic v) =>
                  MapEntry<String, dynamic>(k.toString(), v)),
            ));
          }
        }
      } else {
        _handleMessage(payload);
      }
    } catch (error, stack) {
      _log('THROW in _onSocketData: $error');
      _log('  stack: ${stack.toString().split("\n").first}');
      _messageController.add(UnknownMessage(
        rawType: 'parse_error',
        payload: <String, dynamic>{'error': error.toString()},
      ));
    }
  }

  void _handleMessage(Map<String, dynamic> json) {
    final DcssMessage message = DcssMessageFactory.fromJson(json);
    _messageController.add(message);
    _log('MSG: ${message.type}');

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
        _log('set_game_links → playing: $gameId');
        sendOutgoing(PlayRequest(gameId: gameId));
      }
      return;
    }
    if (message is GoLobbyMessage) {
      _log('go_lobby received');
      state = state.copyWith(
        status: WebsocketConnectionStatus.error,
        errorMessage: 'Server sent go_lobby — game ended or invalid game ID.',
        isLoggedIn: false,
      );
      return;
    }
    if (message is LobbyCompleteMessage) {
      if (_credentials != null && !state.isLoggedIn) {
        _log('lobby_complete → sending LoginRequest');
        sendOutgoing(LoginRequest(
          username: _credentials!.username,
          password: _credentials!.password,
        ));
      }
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
      if (message.mode == 1) sendOutgoing(const PongRequest());
      return;
    }
  }

  void _onSocketError(Object error) {
    _log('ERROR from stream: $error');
    _scheduleReconnect(error.toString());
  }

  void _onSocketDone() {
    _log('Stream done (socket closed)');
    _scheduleReconnect('Socket connection closed.');
  }

  void _scheduleReconnect(String reason) {
    if (_manualDisconnect || _credentials == null) {
      if (state.status == WebsocketConnectionStatus.error) return;
      state = state.copyWith(
        status: WebsocketConnectionStatus.disconnected,
        errorMessage: reason,
        reconnectAttempt: 0,
        isLoggedIn: false,
      );
      return;
    }

    final int attempt = state.reconnectAttempt + 1;

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
