import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dcss_protocol.dart';
import '../network/websocket_manager.dart';

class PlayerStats {
  const PlayerStats({
    this.hp = 0,
    this.mhp = 0,
    this.mp = 0,
    this.mmp = 0,
    this.ac = 0,
    this.ev = 0,
    this.sh = 0,
    this.str = 0,
    this.intelligence = 0,
    this.dex = 0,
    this.place = '',
    this.depth = 0,
    this.xl = 0,
    this.gold = 0,
    this.expPool = 0,
    this.status = const <String>[],
  });

  final int hp;
  final int mhp;
  final int mp;
  final int mmp;
  final int ac;
  final int ev;
  final int sh;
  final int str;
  final int intelligence;
  final int dex;
  final String place;
  final int depth;
  final int xl;
  final int gold;
  final int expPool;
  final List<String> status;

  PlayerStats copyWith({
    int? hp,
    int? mhp,
    int? mp,
    int? mmp,
    int? ac,
    int? ev,
    int? sh,
    int? str,
    int? intelligence,
    int? dex,
    String? place,
    int? depth,
    int? xl,
    int? gold,
    int? expPool,
    List<String>? status,
  }) {
    return PlayerStats(
      hp: hp ?? this.hp,
      mhp: mhp ?? this.mhp,
      mp: mp ?? this.mp,
      mmp: mmp ?? this.mmp,
      ac: ac ?? this.ac,
      ev: ev ?? this.ev,
      sh: sh ?? this.sh,
      str: str ?? this.str,
      intelligence: intelligence ?? this.intelligence,
      dex: dex ?? this.dex,
      place: place ?? this.place,
      depth: depth ?? this.depth,
      xl: xl ?? this.xl,
      gold: gold ?? this.gold,
      expPool: expPool ?? this.expPool,
      status: status ?? this.status,
    );
  }
}

class GameMessage {
  const GameMessage({
    required this.text,
    required this.channel,
    required this.timestamp,
  });

  final String text;
  final int channel;
  final DateTime timestamp;
}

class MenuItemState {
  const MenuItemState({
    required this.hotkey,
    required this.text,
    required this.tiles,
  });

  final int hotkey;
  final String text;
  final List<int> tiles;
}

class MenuState {
  const MenuState({
    required this.id,
    required this.title,
    required this.tag,
    required this.flags,
    required this.items,
    this.scrollOffset,
  });

  final String id;
  final String title;
  final String tag;
  final int flags;
  final List<MenuItemState> items;
  final int? scrollOffset;

  MenuState copyWith({
    String? id,
    String? title,
    String? tag,
    int? flags,
    List<MenuItemState>? items,
    int? scrollOffset,
  }) {
    return MenuState(
      id: id ?? this.id,
      title: title ?? this.title,
      tag: tag ?? this.tag,
      flags: flags ?? this.flags,
      items: items ?? this.items,
      scrollOffset: scrollOffset ?? this.scrollOffset,
    );
  }
}

class GameState {
  const GameState({
    required this.tileGrid,
    required this.playerStats,
    required this.messageLog,
    required this.activeMenu,
    required this.playerPos,
    required this.versionInfo,
    required this.txtPayload,
    required this.lobbyEntries,
  });

  factory GameState.initial() {
    return const GameState(
      tileGrid: <Point<int>, List<int>>{},
      playerStats: PlayerStats(),
      messageLog: <GameMessage>[],
      activeMenu: null,
      playerPos: Point<int>(0, 0),
      versionInfo: null,
      txtPayload: null,
      lobbyEntries: <Map<String, dynamic>>[],
    );
  }

  final Map<Point<int>, List<int>> tileGrid;
  final PlayerStats playerStats;
  final List<GameMessage> messageLog;
  final MenuState? activeMenu;
  final Point<int> playerPos;
  final String? versionInfo;
  final Map<String, dynamic>? txtPayload;
  final List<Map<String, dynamic>> lobbyEntries;

  GameState copyWith({
    Map<Point<int>, List<int>>? tileGrid,
    PlayerStats? playerStats,
    List<GameMessage>? messageLog,
    MenuState? activeMenu,
    bool clearMenu = false,
    Point<int>? playerPos,
    String? versionInfo,
    bool clearVersion = false,
    Map<String, dynamic>? txtPayload,
    bool clearTxtPayload = false,
    List<Map<String, dynamic>>? lobbyEntries,
  }) {
    return GameState(
      tileGrid: tileGrid ?? this.tileGrid,
      playerStats: playerStats ?? this.playerStats,
      messageLog: messageLog ?? this.messageLog,
      activeMenu: clearMenu ? null : (activeMenu ?? this.activeMenu),
      playerPos: playerPos ?? this.playerPos,
      versionInfo: clearVersion ? null : (versionInfo ?? this.versionInfo),
      txtPayload: clearTxtPayload ? null : (txtPayload ?? this.txtPayload),
      lobbyEntries: lobbyEntries ?? this.lobbyEntries,
    );
  }
}

final gameStateProvider = StateNotifierProvider<GameStateNotifier, GameState>(
  (Ref ref) => GameStateNotifier(ref),
);

class GameStateNotifier extends StateNotifier<GameState> {
  GameStateNotifier(Ref ref) : super(GameState.initial()) {
    _websocketManager = ref.read(websocketProvider.notifier);
    _messageSubscription = _websocketManager.messages.listen(_onMessage);
  }
  late final WebsocketManager _websocketManager;

  StreamSubscription<DcssMessage>? _messageSubscription;

  void _onMessage(DcssMessage message) {
    if (message is MapUpdateMessage) {
      _handleMapUpdate(message);
      return;
    }

    if (message is PlayerUpdateMessage) {
      _handlePlayerUpdate(message);
      return;
    }

    if (message is GameLogMessage) {
      _handleGameMessage(message);
      return;
    }

    if (message is MenuMessage) {
      _setMenu(_menuFromMessage(message));
      return;
    }

    if (message is MenuScrollMessage) {
      _handleMenuScroll(message);
      return;
    }

    if (message is CloseMenuMessage || message is UiPopMessage) {
      dismissMenu();
      return;
    }

    if (message is UiPushMessage) {
      final MenuMessage? menu = message.asMenuMessage();
      if (menu != null) {
        _setMenu(_menuFromMessage(menu));
      }
      return;
    }

    if (message is TxtMessage) {
      state = state.copyWith(txtPayload: message.payload);
      return;
    }

    if (message is VersionMessage) {
      state = state.copyWith(
        versionInfo: message.versionString ?? jsonEncode(message.payload),
      );
      return;
    }

    if (message is LobbyEntryMessage) {
      final List<Map<String, dynamic>> updatedEntries =
          List<Map<String, dynamic>>.from(state.lobbyEntries)
            ..add(message.payload);
      if (updatedEntries.length > 200) {
        updatedEntries.removeRange(0, updatedEntries.length - 200);
      }
      state = state.copyWith(lobbyEntries: updatedEntries);
    }
  }

  void _handleMapUpdate(MapUpdateMessage message) {
    final Map<Point<int>, List<int>> updatedGrid =
        Map<Point<int>, List<int>>.from(state.tileGrid);

    for (final MapCellDelta cell in message.cells) {
      updatedGrid[Point<int>(cell.x, cell.y)] =
          List<int>.unmodifiable(cell.tiles);
    }

    final Point<int> newPlayerPos;
    if (message.playerX != null && message.playerY != null) {
      newPlayerPos = Point<int>(message.playerX!, message.playerY!);
    } else {
      newPlayerPos = state.playerPos;
    }

    state = state.copyWith(tileGrid: updatedGrid, playerPos: newPlayerPos);
  }

  void _handlePlayerUpdate(PlayerUpdateMessage message) {
    final PlayerStats current = state.playerStats;
    final PlayerStats stats = current.copyWith(
      hp: message.hp ?? current.hp,
      mhp: message.mhp ?? current.mhp,
      mp: message.mp ?? current.mp,
      mmp: message.mmp ?? current.mmp,
      ac: message.ac ?? current.ac,
      ev: message.ev ?? current.ev,
      sh: message.sh ?? current.sh,
      str: message.str ?? current.str,
      intelligence: message.intelligence ?? current.intelligence,
      dex: message.dex ?? current.dex,
      place: message.place ?? current.place,
      depth: message.depth ?? current.depth,
      xl: message.xl ?? current.xl,
      gold: message.gold ?? current.gold,
      expPool: message.expPool ?? current.expPool,
      status: message.status ?? current.status,
    );

    Point<int>? playerPos;
    if (message.x != null && message.y != null) {
      playerPos = Point<int>(message.x!, message.y!);
    }

    state = state.copyWith(playerStats: stats, playerPos: playerPos);
  }

  void _handleGameMessage(GameLogMessage message) {
    final List<GameMessage> updatedLog = List<GameMessage>.from(state.messageLog)
      ..add(
        GameMessage(
          text: message.text,
          channel: message.channel,
          timestamp: DateTime.now(),
        ),
      );

    if (updatedLog.length > 1000) {
      updatedLog.removeRange(0, updatedLog.length - 1000);
    }

    state = state.copyWith(messageLog: updatedLog);
  }

  void _setMenu(MenuState menu) {
    state = state.copyWith(activeMenu: menu);
  }

  void _handleMenuScroll(MenuScrollMessage message) {
    final MenuState? activeMenu = state.activeMenu;
    if (activeMenu == null) {
      return;
    }
    final int? offset = message.offset;
    if (offset == null) {
      return;
    }

    state = state.copyWith(activeMenu: activeMenu.copyWith(scrollOffset: offset));
  }

  MenuState _menuFromMessage(MenuMessage message) {
    final List<MenuItemState> items = message.items
        .map(
          (MenuItemMessage item) => MenuItemState(
            hotkey: item.hotkey,
            text: item.text,
            tiles: item.tiles,
          ),
        )
        .toList(growable: false);

    return MenuState(
      id: message.id,
      title: message.title,
      tag: message.tag,
      flags: message.flags,
      items: items,
    );
  }

  void sendKeyCode(int keycode) {
    _websocketManager.sendKeyCode(keycode);
  }

  void sendTileClick(Point<int> point) {
    _websocketManager.sendTileClick(x: point.x, y: point.y);
  }

  void dismissMenu() {
    state = state.copyWith(clearMenu: true);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
