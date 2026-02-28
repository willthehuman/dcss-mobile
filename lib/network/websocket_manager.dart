import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/io.dart';

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

  void sendTileClick({required int x, required int y, int button = 1}) {
    sendOutgoing(TileClickRequest(x: x, y: y, button: button));
  }

  Future<void> _openSocket({required bool isReconnect}) async {
    final _Credentials? credentials = _credentials;
    if (credentials == null) {
      return;
    }

    await _closeChannel();

    state = state.copyWith(
      status: isReconnect
          ? WebsocketConnectionStatus.reconnecting
          : WebsocketConnectionStatus.connecting,
      isLoggedIn: false,
      clearError: true,
    );

    try {
      final Uri uri = Uri.parse(credentials.serverUrl);
      _channel = IOWebSocketChannel.connect(uri);
      state = state.copyWith(
        status: WebsocketConnectionStatus.authenticating,
        clearError: true,
      );

      _channelSubscription = _channel!.stream.listen(
        _onSocketData,
        onError: _onSocketError,
        onDone: _onSocketDone,
        cancelOnError: true,
      );

      sendOutgoing(
        LoginRequest(
          username: credentials.username,
          password: credentials.password,
        ),
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
        rawText = utf8.decode(rawEvent);
      } else {
        rawText = rawEvent.toString();
      }

      final Map<String, dynamic> payload = parseJsonMap(rawText);
      final DcssMessage message = DcssMessageFactory.fromJson(payload);
      _messageController.add(message);

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

        sendOutgoing(const GetLobbiedGamesRequest());
        return;
      }

      if (message is LobbyCompleteMessage) {
        if (_credentials != null && state.isLoggedIn) {
          sendOutgoing(PlayRequest(gameId: _credentials!.gameId));
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
    } catch (error) {
      _messageController.add(
        UnknownMessage(
          rawType: 'parse_error',
          payload: <String, dynamic>{'error': error.toString()},
        ),
      );
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
