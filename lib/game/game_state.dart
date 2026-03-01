import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dcss_mobile/settings/app_settings.dart';
import 'package:flutter/foundation.dart';
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

class TextInputState {
  const TextInputState({
    required this.tag,
    required this.inputType,
    this.prompt,
    this.prefill,
    this.maxlen,
  });

  final String tag;
  final String inputType;
  final String? prompt;
  final String? prefill;
  final int? maxlen;

  TextInputState copyWith({
    String? prefill,
  }) {
    return TextInputState(
      tag: tag,
      inputType: inputType,
      prompt: prompt,
      prefill: prefill ?? this.prefill,
      maxlen: maxlen,
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
    required this.cursorPos,
    required this.versionInfo,
    required this.txtPayload,
    required this.lobbyEntries,
    required this.textInputState,
    this.spectatorCount = 0,
  });

  factory GameState.initial() {
    return const GameState(
      tileGrid: <Point<int>, List<int>>{},
      playerStats: PlayerStats(),
      messageLog: <GameMessage>[],
      activeMenu: null,
      playerPos: Point<int>(0, 0),
      cursorPos: null,
      versionInfo: null,
      txtPayload: null,
      lobbyEntries: <Map<String, dynamic>>[],
      textInputState: null,
      spectatorCount: 0,
    );
  }

  final Map<Point<int>, List<int>> tileGrid;
  final PlayerStats playerStats;
  final List<GameMessage> messageLog;
  final MenuState? activeMenu;
  final Point<int> playerPos;
  final Point<int>? cursorPos;
  final String? versionInfo;
  final Map<String, dynamic>? txtPayload;
  final List<Map<String, dynamic>> lobbyEntries;
  final TextInputState? textInputState;
  final int spectatorCount;

  GameState copyWith({
    Map<Point<int>, List<int>>? tileGrid,
    PlayerStats? playerStats,
    List<GameMessage>? messageLog,
    MenuState? activeMenu,
    bool clearMenu = false,
    Point<int>? playerPos,
    Point<int>? cursorPos,
    bool clearCursorPos = false,
    String? versionInfo,
    bool clearVersion = false,
    Map<String, dynamic>? txtPayload,
    bool clearTxtPayload = false,
    List<Map<String, dynamic>>? lobbyEntries,
    TextInputState? textInputState,
    bool clearTextInput = false,
    int? spectatorCount,
  }) {
    return GameState(
      tileGrid: tileGrid ?? this.tileGrid,
      playerStats: playerStats ?? this.playerStats,
      messageLog: messageLog ?? this.messageLog,
      activeMenu: clearMenu ? null : (activeMenu ?? this.activeMenu),
      playerPos: playerPos ?? this.playerPos,
      cursorPos: clearCursorPos ? null : (cursorPos ?? this.cursorPos),
      versionInfo: clearVersion ? null : (versionInfo ?? this.versionInfo),
      txtPayload: clearTxtPayload ? null : (txtPayload ?? this.txtPayload),
      lobbyEntries: lobbyEntries ?? this.lobbyEntries,
      textInputState:
          clearTextInput ? null : (textInputState ?? this.textInputState),
      spectatorCount: spectatorCount ?? this.spectatorCount,
    );
  }
}

final gameStateProvider = StateNotifierProvider<GameStateNotifier, GameState>(
  (Ref ref) => GameStateNotifier(ref),
);

class GameStateNotifier extends StateNotifier<GameState> {
  GameStateNotifier(Ref ref) : super(GameState.initial()) {
    _ref = ref;
    _websocketManager = ref.read(websocketProvider.notifier);
    _messageSubscription = _websocketManager.messages.listen(_enqueueMessage);
  }

  late final Ref _ref;
  late final WebsocketManager _websocketManager;

  StreamSubscription<DcssMessage>? _messageSubscription;
  final Map<Point<int>, Map<String, dynamic>> _rawTileData =
      <Point<int>, Map<String, dynamic>>{};

  final List<DcssMessage> _messageQueue = <DcssMessage>[];
  bool _isProcessingQueue = false;

  void _enqueueMessage(DcssMessage message) {
    _messageQueue.add(message);
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (_messageQueue.isNotEmpty) {
      final DcssMessage message = _messageQueue.removeAt(0);

      if (message is DelayMessage) {
        await Future<void>.delayed(Duration(milliseconds: message.t));
        continue;
      }

      _handleMessageSync(message);
    }

    _isProcessingQueue = false;
  }

  void _handleMessageSync(DcssMessage message) {
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

    if (message is UpdateMenuMessage) {
      final MenuState? current = state.activeMenu;
      if (current != null) {
        final Map<String, dynamic> p = message.payload;
        List<MenuItemState> updatedItems = current.items;

        if (p.containsKey('total_items')) {
          final int total = p['total_items'] is int
              ? p['total_items']
              : (int.tryParse(p['total_items'].toString()) ??
                  updatedItems.length);
          if (total < updatedItems.length) {
            updatedItems = updatedItems.sublist(0, total);
          }
        }

        if (p.containsKey('items')) {
          final dynamic rawItems = p['items'];
          if (rawItems is List) {
            final List<MenuItemState> newItems = [];
            for (final dynamic item in rawItems) {
              if (item is Map) {
                final parsed =
                    MenuItemMessage.fromJson(Map<String, dynamic>.from(item));
                newItems.add(MenuItemState(
                    hotkey: parsed.hotkey,
                    text: parsed.text,
                    tiles: parsed.tiles));
              }
            }
            updatedItems = newItems;
          }
        }

        state = state.copyWith(
          activeMenu: current.copyWith(
            id: p.containsKey('id') ? p['id'].toString() : current.id,
            title:
                p.containsKey('title') ? p['title'].toString() : current.title,
            tag: p.containsKey('tag') ? p['tag'].toString() : current.tag,
            flags: p.containsKey('flags')
                ? (p['flags'] is int
                    ? p['flags']
                    : int.tryParse(p['flags'].toString()) ?? current.flags)
                : current.flags,
            items: updatedItems,
          ),
        );
      }
      return;
    }

    if (message is UpdateMenuItemsMessage) {
      final MenuState? current = state.activeMenu;
      if (current != null) {
        final Map<String, dynamic> p = message.payload;
        final int chunkStart = p['chunk_start'] is int
            ? p['chunk_start']
            : (int.tryParse(p['chunk_start']?.toString() ?? '0') ?? 0);
        final dynamic rawItems = p['items'];

        if (rawItems is List) {
          final List<MenuItemState> updatedItems =
              List<MenuItemState>.from(current.items);

          for (int i = 0; i < rawItems.length; i++) {
            final dynamic item = rawItems[i];
            if (item is Map) {
              final parsed =
                  MenuItemMessage.fromJson(Map<String, dynamic>.from(item));
              final stateItem = MenuItemState(
                  hotkey: parsed.hotkey,
                  text: parsed.text,
                  tiles: parsed.tiles);
              final int targetIndex = chunkStart + i;
              if (targetIndex < updatedItems.length) {
                updatedItems[targetIndex] = stateItem;
              } else {
                updatedItems.add(stateItem);
              }
            }
          }
          state =
              state.copyWith(activeMenu: current.copyWith(items: updatedItems));
        }
      }
      return;
    }

    if (message is MenuScrollMessage) {
      _handleMenuScroll(message);
      return;
    }
    if (message is GameLogBatchMessage) {
      for (final GameLogMessage m in message.messages) {
        _handleGameMessage(m);
      }
      return;
    }
    if (message is CursorMessage) {
      if (message.x >= 0 && message.y >= 0) {
        state = state.copyWith(cursorPos: Point<int>(message.x, message.y));
      } else {
        state = state.copyWith(clearCursorPos: true);
      }
      return;
    }

    if (message is CloseMenuMessage) {
      state = state.copyWith(clearMenu: true);
      return;
    }

    if (message is UiPopMessage) {
      state = state.copyWith(clearMenu: true, clearTxtPayload: true);
      return;
    }

    if (message is UiPushMessage) {
      final String uiType = message.payload['type']?.toString() ?? '';
      debugPrint(
          '[ui-push] type=$uiType keys=${message.payload.keys.toList()}');

      // Types that should render as rich text overlays (TxtOverlay)
      const Set<String> txtOverlayTypes = <String>{
        'formatted-scroller',
        'describe-generic',
        'describe-feature-wide',
        'describe-item',
        'describe-spell',
        'describe-cards',
        'describe-god',
        'describe-monster',
        'game-over',
        'version',
      };

      if (txtOverlayTypes.contains(uiType)) {
        state = state.copyWith(
          txtPayload: _uiPushToTxtPayload(message),
          clearMenu: true,
        );
        return;
      }

      // Convert remaining ui-push payloads into MenuOverlay.
      final MenuMessage menu = message.asMenuMessage();
      _setMenu(_menuFromMessage(menu));
      return;
    }

    if (message is InitInputMessage) {
      state = state.copyWith(
        textInputState: TextInputState(
          tag: message.tag,
          inputType: message.inputType,
          prompt: message.prompt,
          prefill: message.prefill,
          maxlen: message.maxlen,
        ),
      );
      return;
    }

    if (message is CloseInputMessage) {
      state = state.copyWith(clearTextInput: true);
      return;
    }

    if (message is UpdateInputMessage) {
      final TextInputState? current = state.textInputState;
      if (current != null && message.inputText != null) {
        state = state.copyWith(
          textInputState: current.copyWith(prefill: message.inputText),
        );
      }
      return;
    }

    if (message is TxtMessage) {
      final dynamic lines = message.payload['lines'];
      final bool hasContent = lines != null &&
          ((lines is Map && lines.isNotEmpty) ||
              (lines is List && lines.isNotEmpty));
      if (hasContent) {
        state = state.copyWith(txtPayload: message.payload);
      } else {
        state = state.copyWith(clearTxtPayload: true);
      }
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

    if (message is UpdateSpectatorsMessage) {
      state = state.copyWith(spectatorCount: message.count);
      return;
    }

    if (message is ChatMessage) {
      // Channel 98 is reserved for chat messages (channel 99 is unknown/debug)
      _handleGameMessage(GameLogMessage(
        text: '${message.sender}: ${message.text}',
        channel: 98,
      ));
      return;
    }

    if (message is HtmlMessage) {
      debugPrint('[html] id=${message.id}');
      return;
    }

    if (message is OptionsMessage) {
      debugPrint('[options] received');
      return;
    }

    if (message is LayoutMessage) {
      debugPrint('[layout] layout=${message.layout}');
      return;
    }

    if (message is UiStateMessage) {
      debugPrint('[ui_state] state=${message.uiState}');
      return;
    }

    // Temporary debug: dump all unknown messages to the game log
    if (message is UnknownMessage) {
      final String raw = jsonEncode(message.payload);
      final String preview = raw.length > 120 ? raw.substring(0, 120) : raw;
      _handleGameMessage(GameLogMessage(
        text: '[UNKNOWN:${message.rawType}] $preview',
        channel: 99,
      ));
    }

    if (message is GameClientMessage) {
      // Try version (hex hash) first, then package path
      final String key =
          message.version.isNotEmpty ? message.version : message.package;
      if (key.isNotEmpty) {
        _ref.read(tileBaseUrlProvider.notifier).state = key;
      }
      return;
    }
  }

  /// Convert a text-based ui-push payload into a TxtOverlay-compatible map.
  Map<String, dynamic> _uiPushToTxtPayload(UiPushMessage message) {
    final Map<String, dynamic> p = message.payload;
    final List<dynamic> lines = <dynamic>[];

    void addLine(String text, {int fg = 7}) {
      // Strip HTML tags
      final String clean = text.replaceAll(RegExp(r'<[^>]*>'), '');
      for (final String line in clean.split('\n')) {
        lines.add(<dynamic>[
          <dynamic>[line, fg]
        ]);
      }
    }

    void addSpacer() => addLine('');

    // Header / Title in white
    final String? title = p['title']?.toString();
    if (title != null && title.isNotEmpty) {
      addLine(title, fg: 15);
      addSpacer();
    }

    // Name (describe-god uses 'name' instead of 'title')
    final String? name = p['name']?.toString();
    if (name != null && name.isNotEmpty && (title == null || title.isEmpty)) {
      addLine(name, fg: 15);
      addSpacer();
    }

    // Prompt in yellow
    final String? prompt = p['prompt']?.toString();
    if (prompt != null && prompt.isNotEmpty) {
      addLine(prompt, fg: 14);
      addSpacer();
    }

    // Information (version popup)
    final String? information = p['information']?.toString();
    if (information != null && information.isNotEmpty) {
      addLine(information, fg: 15);
      addSpacer();
    }

    // Body / text / description in light gray
    for (final String key in <String>['body', 'text', 'description']) {
      final String? val = p[key]?.toString();
      if (val != null && val.isNotEmpty) {
        addLine(val, fg: 7);
        addSpacer();
      }
    }

    // Feats (describe-feature-wide)
    final dynamic feats = p['feats'];
    if (feats is List && feats.isNotEmpty) {
      for (final dynamic feat in feats) {
        if (feat is Map) {
          final String? featTitle = feat['title']?.toString();
          if (featTitle != null && featTitle.isNotEmpty) {
            addLine(featTitle, fg: 15);
          }
          final String? featBody = feat['body']?.toString();
          if (featBody != null && featBody.isNotEmpty) {
            addLine(featBody, fg: 7);
          }
          addSpacer();
        } else if (feat is String) {
          addLine(feat, fg: 7);
        }
      }
    }

    // Favour / piety (describe-god)
    final String? favour = p['favour']?.toString();
    if (favour != null && favour.isNotEmpty) {
      addLine('Favour: $favour', fg: 11);
    }

    // Powers (describe-god)
    final String? powers = p['powers']?.toString();
    if (powers != null && powers.isNotEmpty) {
      addSpacer();
      addLine('--- Powers ---', fg: 14);
      addLine(powers, fg: 7);
    }

    // Powers list (describe-god)
    final String? powersList = p['powers_list']?.toString();
    if (powersList != null && powersList.isNotEmpty) {
      addLine(powersList, fg: 7);
    }

    // Wrath (describe-god)
    final String? wrath = p['wrath']?.toString();
    if (wrath != null && wrath.isNotEmpty) {
      addSpacer();
      addLine('--- Wrath ---', fg: 12);
      addLine(wrath, fg: 7);
    }

    // Quote (describe-monster)
    final String? quote = p['quote']?.toString();
    if (quote != null && quote.isNotEmpty) {
      addSpacer();
      addLine(quote, fg: 8);
    }

    // Status (describe-monster)
    final String? monsterStatus = p['status']?.toString();
    if (monsterStatus != null && monsterStatus.isNotEmpty) {
      addSpacer();
      addLine('--- Status ---', fg: 14);
      addLine(monsterStatus, fg: 7);
    }

    // Actions (describe-item)
    final String? actions = p['actions']?.toString();
    if (actions != null && actions.isNotEmpty) {
      addSpacer();
      addLine(actions, fg: 11);
    }

    // Features / changes (version popup)
    for (final String key in <String>['features', 'changes']) {
      final String? val = p[key]?.toString();
      if (val != null && val.isNotEmpty) {
        addSpacer();
        addLine(val, fg: 7);
      }
    }

    // Info table (describe-god)
    final String? infoTable = p['info_table']?.toString();
    if (infoTable != null && infoTable.isNotEmpty) {
      addSpacer();
      addLine(infoTable, fg: 7);
    }

    // Highlight text (formatted-scroller)
    final String? highlight = p['highlight']?.toString();
    if (highlight != null && highlight.isNotEmpty) {
      // We don't do real highlighting, but log it for debug
      debugPrint('[ui-push] highlight: $highlight');
    }

    // "More" prompt at the bottom in dark gray
    final String? more = p['more']?.toString();
    if (more != null && more.isNotEmpty) {
      addSpacer();
      addLine(more, fg: 8);
    } else {
      addSpacer();
      addLine('[Tap to dismiss]', fg: 8);
    }

    return <String, dynamic>{'lines': lines};
  }

  void _handleMapUpdate(MapUpdateMessage message) {
    if (message.clear) {
      _rawTileData.clear();
    }

    final Map<Point<int>, List<int>> updatedGrid = message.clear
        ? <Point<int>, List<int>>{} // start fresh
        : Map<Point<int>, List<int>>.from(state.tileGrid); // or build on

    for (final MapCellDelta cell in message.cells) {
      final Point<int> pt = Point<int>(cell.x, cell.y);

      // 1. Merge the raw json `t` payload into our persistent store
      Map<String, dynamic>? rawData = _rawTileData[pt];
      if (cell.t != null) {
        rawData ??= <String, dynamic>{};
        final Map<String, dynamic> delta = cell.t!;

        if (delta.containsKey('bg')) rawData['bg'] = delta['bg'];
        if (delta.containsKey('fg')) rawData['fg'] = delta['fg'];
        if (delta.containsKey('cloud')) rawData['cloud'] = delta['cloud'];
        if (delta.containsKey('ov')) rawData['ov'] = delta['ov'];

        if (delta.containsKey('doll')) {
          final dynamic doll = delta['doll'];
          if (doll is List && doll.isNotEmpty) {
            debugPrint('[DOLL DEBUG] Received cell doll: $doll');
          }
          if (doll is List && doll.isEmpty) {
            rawData.remove('doll');
          } else {
            rawData['doll'] = doll;
          }
        }

        if (delta.containsKey('mcache')) {
          final dynamic mcache = delta['mcache'];
          if (mcache is List && mcache.isEmpty) {
            rawData.remove('mcache');
          } else {
            rawData['mcache'] = mcache;
          }
        }

        _rawTileData[pt] = rawData;
      }

      // 2. Resolve tile indices from the newly merged raw payload
      final List<int> resolvedTiles = rawData != null
          ? MapUpdateMessage.parseTileField(rawData)
          : cell.tiles;

      // Visibility is EXACTLY determined by the server's update delta merging into our state!
      // If the merged state contains 'fg', 'doll', or 'mcache' keys, or if the 'bg' tile carries
      // no dark rendering flags, it represents an in-LOS cell.
      final bool currentlyVisible = rawData != null &&
          (MapUpdateMessage.tileHasFgData(rawData) ||
              MapUpdateMessage.tileBgIsVisible(rawData));

      if (currentlyVisible) {
        // Visible cell: Store with a non-negative mf prefix so the renderer
        // does NOT apply the remembered-cell overlay.
        updatedGrid[pt] =
            List<int>.unmodifiable(<int>[cell.mf, ...resolvedTiles]);
      } else {
        // Out-of-LOS update. Memory cells shouldn't retain volatile things
        // like monsters (doll) or temporary spell effects (mcache, cloud).
        // Only keep bg and fg (items/terrain).
        if (rawData != null) {
          rawData.remove('doll');
          rawData.remove('mcache');
          rawData.remove('cloud');

          // Re-parse the cleaned up raw data to ensure ghosts aren't drawn
          final List<int> cleanedTiles =
              MapUpdateMessage.parseTileField(rawData);
          updatedGrid[pt] =
              List<int>.unmodifiable(<int>[-(cell.mf + 1), ...cleanedTiles]);
        } else if (updatedGrid.containsKey(pt)) {
          final List<int> existing = updatedGrid[pt]!;
          final List<int> existingTiles = existing.length > 1
              ? existing
                  .sublist(1)
                  .where((int t) => t > 0)
                  .toList(growable: false)
              : const <int>[];
          updatedGrid[pt] =
              List<int>.unmodifiable(<int>[-(cell.mf + 1), ...existingTiles]);
        } else {
          // Fallback if cell has never been seen (should be very rare or strictly unexplored)
          updatedGrid[pt] =
              List<int>.unmodifiable(<int>[-(cell.mf + 1), ...cell.tiles]);
        }
      }
    }

    final Point<int> newPlayerPos;
    if (message.playerX != null && message.playerY != null) {
      newPlayerPos = Point<int>(message.playerX!, message.playerY!);
    } else {
      newPlayerPos = state.playerPos;
    }
    debugPrint('[GameState] playerPos updated → $newPlayerPos');
    Point<int>? cursorPos;
    bool clearCursor = false;
    if (message.cursorX != null && message.cursorY != null) {
      if (message.cursorX! >= 0 && message.cursorY! >= 0) {
        cursorPos = Point<int>(message.cursorX!, message.cursorY!);
      } else {
        clearCursor = true;
      }
    }

    state = state.copyWith(
      tileGrid: updatedGrid,
      playerPos: newPlayerPos,
      cursorPos: cursorPos,
      clearCursorPos: clearCursor,
    );
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

    // Do NOT update playerPos here — only vgrdc from map messages
    // should control the viewport center.
    state = state.copyWith(playerStats: stats);
  }

  void _handleGameMessage(GameLogMessage message) {
    final List<GameMessage> updatedLog =
        List<GameMessage>.from(state.messageLog)
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

    state =
        state.copyWith(activeMenu: activeMenu.copyWith(scrollOffset: offset));
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

  void sendTextInput(String text) {
    _websocketManager.sendTextInput(text);
  }

  void sendTileClick(Point<int> point) {
    _websocketManager.sendTileClick(x: point.x, y: point.y);
  }

  void dismissMenu() {
    sendKeyCode(27); // ESC to tell server we cancelled
    state = state.copyWith(clearMenu: true);
  }

  void dismissTextInput() {
    sendKeyCode(27); // ESC to tell server we cancelled
    state = state.copyWith(clearTextInput: true);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
