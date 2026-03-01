import 'dart:convert';

import 'package:flutter/foundation.dart';

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

List<int> _asIntList(dynamic value) {
  if (value is! List) {
    return const <int>[];
  }
  return value.map((dynamic item) => _asInt(item)).toList(growable: false);
}

List<String> _asStringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((dynamic item) => item?.toString() ?? '')
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}

Map<String, dynamic> parseJsonMap(String raw) {
  final dynamic decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.map(
      (dynamic key, dynamic value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
  }
  throw const FormatException('Expected top-level JSON object');
}

abstract class DcssMessage {
  const DcssMessage();

  String get type;
}

class UnknownMessage extends DcssMessage {
  const UnknownMessage({required this.rawType, required this.payload});

  final String rawType;
  final Map<String, dynamic> payload;

  @override
  String get type => rawType;
}

class PingMessage extends DcssMessage {
  const PingMessage();

  @override
  String get type => 'ping';
}

class LoginSuccessMessage extends DcssMessage {
  const LoginSuccessMessage();

  @override
  String get type => 'login_success';
}

class LoginFailMessage extends DcssMessage {
  const LoginFailMessage({required this.reason});

  final String reason;

  @override
  String get type => 'login_fail';
}

class MapCellDelta {
  const MapCellDelta({
    required this.x,
    required this.y,
    required this.tiles,
    this.mf = 0,
    this.hasTileData = false,
    this.hasFgData = false,
  });

  final int x;
  final int y;
  /// All tile indices for this cell (bg, fg/doll/mcache, cloud, ov) using the
  /// global index map built by [TileLoaderService].
  final List<int> tiles;
  final int mf;
  /// True when the server sent a `t` field for this cell (vs. mf-only update).
  final bool hasTileData;
  /// True when the `t` field contained fg, doll, or mcache data (cell visible).
  final bool hasFgData;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'x': x,
      'y': y,
      't': tiles,
    };
  }
}

class MapUpdateMessage extends DcssMessage {
  const MapUpdateMessage({
    required this.cells,
    this.playerX,
    this.playerY,
    this.cursorX,
    this.cursorY,
    this.clear = false,
  });

  final List<MapCellDelta> cells;
  final int? playerX;
  final int? playerY;
  final int? cursorX;
  final int? cursorY;
  final bool clear;
  @override
  String get type => 'map';
  factory MapUpdateMessage.fromJson(Map<String, dynamic> json) {
    int? playerX;
    int? playerY;
    final Map<String, dynamic>? vgrdc = json['vgrdc'] as Map<String, dynamic>?;
    if (vgrdc != null) {
      playerX = (vgrdc['x'] as num).toInt();
      playerY = (vgrdc['y'] as num).toInt();
    }

    final int? cx =
        json.containsKey('cursor_x') ? _asInt(json['cursor_x']) : null;
    final int? cy =
        json.containsKey('cursor_y') ? _asInt(json['cursor_y']) : null;

    final bool clear = json['clear'] == true;

    final List<MapCellDelta> parsedCells = <MapCellDelta>[];
    final dynamic cellsRaw = json['cells'];
    if (cellsRaw is List) {
      int curX = 0;
      int curY = 0;
      for (final dynamic cell in cellsRaw) {
        if (cell is! Map) continue;
        final Map<String, dynamic> c = cell is Map<String, dynamic>
            ? cell
            : Map<String, dynamic>.from(cell);

        if (c.containsKey('x')) curX = _asInt(c['x']);
        if (c.containsKey('y')) curY = _asInt(c['y']);

        final int mf = _asInt(c['mf']);
        final dynamic tField = c['t'];
        parsedCells.add(MapCellDelta(
          x: curX,
          y: curY,
          tiles: _parseTileField(tField),
          mf: mf,
          hasTileData: c.containsKey('t'),
          hasFgData: _tileHasFgData(tField),
        ));
        curX++;
      }
    }

    return MapUpdateMessage(
      cells: parsedCells,
      playerX: playerX,   // ← null when vgrdc absent
      playerY: playerY,   // ← null when vgrdc absent
      cursorX: cx,
      cursorY: cy,
      clear: clear,
    );
  }

  static const int _tileFlagMask = 0xFFFF;

  // Strips rendering flag bits and handles both plain int/num and [lo, hi] formats.
  static int _asTileIndex(dynamic value) {
    if (value is num) return value.toInt() & _tileFlagMask;
    if (value is List && value.isNotEmpty) {
      // [lo, hi] format — lo contains the index + low flags
      return _asInt(value[0]) & _tileFlagMask;
    }
    return 0;
  }

  static List<int> _parseTileField(dynamic t) {
    if (t is! Map) return const <int>[];
    final List<int> layers = <int>[];

    // Background layer
    final dynamic bg = t['bg'];
    if (bg != null) {
      final int bgVal = _asTileIndex(bg);
      if (bgVal > 0) layers.add(bgVal);
    }

    // Foreground layer — doll/mcache indices are global tileidx_t values,
    // identical to fg, so they are masked and used as-is.
    final dynamic doll = t['doll'];
    final dynamic mcache = t['mcache'];
    final dynamic fg = t['fg'];

    if (doll is List && doll.isNotEmpty) {
      for (final dynamic part in doll) {
        if (part is List && part.isNotEmpty) {
          final int idx = _asTileIndex(part[0]);
          if (idx > 0) layers.add(idx);
        }
      }
    } else if (mcache is List && mcache.isNotEmpty) {
      for (final dynamic part in mcache) {
        if (part is List && part.isNotEmpty) {
          final int idx = _asTileIndex(part[0]);
          if (idx > 0) layers.add(idx);
        }
      }
    } else if (fg != null) {
      final int fgVal = _asTileIndex(fg);
      if (fgVal > 0) layers.add(fgVal);
    }

    // Cloud layer
    final dynamic cloud = t['cloud'];
    if (cloud != null) {
      final int cloudVal = _asTileIndex(cloud);
      if (cloudVal > 0) layers.add(cloudVal);
    }

    // Overlay array
    final dynamic ov = t['ov'];
    if (ov is List) {
      for (final dynamic o in ov) {
        final int oVal = _asTileIndex(o);
        if (oVal > 0) layers.add(oVal);
      }
    }

    return layers;
  }

  /// Returns true when the tile field indicates the cell is currently visible.
  ///
  /// The DCSS server always includes the 'fg' key for visible cells (even as
  /// value 0 for empty floor). Out-of-LOS updates only contain 'bg'. Checking
  /// for key presence rather than a non-zero value is therefore the correct
  /// way to distinguish visible cells from remembered (out-of-sight) cells.
  static bool _tileHasFgData(dynamic t) {
    if (t is! Map) return false;
    if (t['doll'] is List && (t['doll'] as List).isNotEmpty) return true;
    if (t['mcache'] is List && (t['mcache'] as List).isNotEmpty) return true;
    return (t as Map).containsKey('fg');
  }
}

class PlayerUpdateMessage extends DcssMessage {
  const PlayerUpdateMessage({
    this.hp,
    this.mhp,
    this.mp,
    this.mmp,
    this.ac,
    this.ev,
    this.sh,
    this.str,
    this.intelligence,
    this.dex,
    this.place,
    this.depth,
    this.xl,
    this.gold,
    this.expPool,
    this.status,
    this.x,
    this.y,
  });

  final int? hp;
  final int? mhp;
  final int? mp;
  final int? mmp;
  final int? ac;
  final int? ev;
  final int? sh;
  final int? str;
  final int? intelligence;
  final int? dex;
  final String? place;
  final int? depth;
  final int? xl;
  final int? gold;
  final int? expPool;
  final List<String>? status;
  final int? x;
  final int? y;

  @override
  String get type => 'player';

  factory PlayerUpdateMessage.fromJson(Map<String, dynamic> json) {
    return PlayerUpdateMessage(
      hp: json.containsKey('hp') ? _asInt(json['hp']) : null,
      mhp: json.containsKey('mhp') ? _asInt(json['mhp']) : null,
      mp: json.containsKey('mp') ? _asInt(json['mp']) : null,
      mmp: json.containsKey('mmp') ? _asInt(json['mmp']) : null,
      ac: json.containsKey('ac') ? _asInt(json['ac']) : null,
      ev: json.containsKey('ev') ? _asInt(json['ev']) : null,
      sh: json.containsKey('sh') ? _asInt(json['sh']) : null,
      str: json.containsKey('str') ? _asInt(json['str']) : null,
      intelligence: json.containsKey('int') ? _asInt(json['int']) : null,
      dex: json.containsKey('dex') ? _asInt(json['dex']) : null,
      place: json.containsKey('place') ? _asString(json['place']) : null,
      depth: json.containsKey('depth') ? _asInt(json['depth']) : null,
      xl: json.containsKey('xl') ? _asInt(json['xl']) : null,
      gold: json.containsKey('gold') ? _asInt(json['gold']) : null,
      expPool: json.containsKey('exp_pool') ? _asInt(json['exp_pool']) : null,
      status: json.containsKey('status') ? _asStringList(json['status']) : null,
      x: json.containsKey('x') ? _asInt(json['x']) : null,
      y: json.containsKey('y') ? _asInt(json['y']) : null,
    );
  }
}

class GameLogMessage extends DcssMessage {
  const GameLogMessage({required this.text, required this.channel});

  final String text;
  final int channel;

  @override
  String get type => 'msg';

  factory GameLogMessage.fromJson(Map<String, dynamic> json) {
    return GameLogMessage(
      text: _asString(json['text']),
      channel: _asInt(json['channel']),
    );
  }
}

class MenuItemMessage {
  const MenuItemMessage({
    required this.hotkey,
    required this.text,
    required this.tiles,
  });

  final int hotkey;
  final String text;
  final List<int> tiles;

  factory MenuItemMessage.fromJson(Map<String, dynamic> json) {
    int parsedHotkey = 0;
    final dynamic hotkeyValue = json['hotkey'];
    if (hotkeyValue is String && hotkeyValue.isNotEmpty) {
      parsedHotkey = hotkeyValue.codeUnitAt(0);
    } else {
      parsedHotkey = _asInt(hotkeyValue);
    }

    return MenuItemMessage(
      hotkey: parsedHotkey,
      text: _asString(json['text']),
      tiles: _asIntList(json['tiles']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'hotkey': hotkey,
      'text': text,
      'tiles': tiles,
    };
  }
}

class MenuMessage extends DcssMessage {
  const MenuMessage({
    required this.id,
    required this.title,
    required this.tag,
    required this.flags,
    required this.items,
  });

  final String id;
  final String title;
  final String tag;
  final int flags;
  final List<MenuItemMessage> items;

  @override
  String get type => 'menu';

  factory MenuMessage.fromJson(Map<String, dynamic> json) {
    final dynamic rawItems = json['items'];
    final List<MenuItemMessage> parsedItems = <MenuItemMessage>[];
    if (rawItems is List) {
      for (final dynamic item in rawItems) {
        if (item is Map<String, dynamic>) {
          parsedItems.add(MenuItemMessage.fromJson(item));
        } else if (item is Map) {
          parsedItems
              .add(MenuItemMessage.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    return MenuMessage(
      id: _asString(json['id']),
      title: _asString(json['title']),
      tag: _asString(json['tag']),
      flags: _asInt(json['flags']),
      items: parsedItems,
    );
  }
}

class MenuScrollMessage extends DcssMessage {
  const MenuScrollMessage({required this.payload});

  final Map<String, dynamic> payload;

  int? get offset {
    if (!payload.containsKey('offset')) {
      return null;
    }
    return _asInt(payload['offset']);
  }

  @override
  String get type => 'menu_scroll';
}

class CloseMenuMessage extends DcssMessage {
  const CloseMenuMessage();

  @override
  String get type => 'close_menu';
}

class UiPushMessage extends DcssMessage {
  const UiPushMessage({required this.payload});

  final Map<String, dynamic> payload;

  MenuMessage? asMenuMessage() {
    final bool hasItems = payload.containsKey('items');
    if (!hasItems) {
      return null;
    }
    return MenuMessage.fromJson(payload);
  }

  @override
  String get type => 'ui-push';
}

class UiPopMessage extends DcssMessage {
  const UiPopMessage({required this.payload});

  final Map<String, dynamic> payload;

  @override
  String get type => 'ui-pop';
}

class CursorMessage extends DcssMessage {
  const CursorMessage({required this.x, required this.y});

  final int x;
  final int y;

  @override
  String get type => 'cursor';

  factory CursorMessage.fromJson(Map<String, dynamic> json) {
    int x = -1;
    int y = -1;
    final dynamic loc = json['loc'];
    if (loc is Map) {
      x = _asInt(loc['x'], fallback: -1);
      y = _asInt(loc['y'], fallback: -1);
    } else {
      if (json.containsKey('x')) {
        x = _asInt(json['x'], fallback: -1);
      }
      if (json.containsKey('y')) {
        y = _asInt(json['y'], fallback: -1);
      }
    }
    return CursorMessage(x: x, y: y);
  }
}

class TxtMessage extends DcssMessage {
  const TxtMessage({required this.payload});

  final Map<String, dynamic> payload;

  @override
  String get type => 'txt';
}

class VersionMessage extends DcssMessage {
  const VersionMessage({required this.payload});

  final Map<String, dynamic> payload;

  String? get versionString {
    if (payload.containsKey('version')) {
      return payload['version']?.toString();
    }
    if (payload.containsKey('text')) {
      return payload['text']?.toString();
    }
    return null;
  }

  @override
  String get type => 'version';
}

class LobbyEntryMessage extends DcssMessage {
  const LobbyEntryMessage({required this.payload});

  final Map<String, dynamic> payload;

  @override
  String get type => 'lobby_entry';
}

class LobbyClearMessage extends DcssMessage {
  const LobbyClearMessage();

  @override
  String get type => 'lobby_clear';
}

class LobbyCompleteMessage extends DcssMessage {
  const LobbyCompleteMessage();

  @override
  String get type => 'lobby_complete';
}

class DcssMessageFactory {
  const DcssMessageFactory._();

  static DcssMessage fromJson(Map<String, dynamic> json) {
    final String type = _asString(json['msg']);
    switch (type) {
      case 'ping':
        return const PingMessage();
      case 'login_success':
        return const LoginSuccessMessage();
      case 'login_fail':
        return LoginFailMessage(reason: _asString(json['reason']));
      case 'map':
        return MapUpdateMessage.fromJson(json);
      case 'player':
        return PlayerUpdateMessage.fromJson(json);
      case 'msg':
        return GameLogMessage.fromJson(json);
      case 'menu':
        return MenuMessage.fromJson(json);
      case 'menu_scroll':
        return MenuScrollMessage(payload: Map<String, dynamic>.from(json));
      case 'close_menu':
        return const CloseMenuMessage();
      case 'ui-push':
        return UiPushMessage(payload: Map<String, dynamic>.from(json));
      case 'ui-pop':
        return UiPopMessage(payload: Map<String, dynamic>.from(json));
      case 'cursor':
        return CursorMessage.fromJson(json);
      case 'txt':
        return TxtMessage(payload: Map<String, dynamic>.from(json));
      case 'version':
        return VersionMessage(payload: Map<String, dynamic>.from(json));
      case 'lobby_entry':
        return LobbyEntryMessage(payload: Map<String, dynamic>.from(json));
      case 'lobby_clear':
        return const LobbyClearMessage();
      case 'lobby_complete':
        return const LobbyCompleteMessage();
      case 'play_error':
        return LoginFailMessage(
            reason: _asString(json['reason'] ?? json['msg']));
      case 'input_mode':
        return InputModeMessage(mode: _asInt(json['mode']));
      case 'set_game_links':
        return SetGameLinksMessage.fromJson(json);
      case 'game_started':
        return const GameStartedMessage();
      case 'go_lobby':
        return const GoLobbyMessage();
      case 'msgs':
        final List<dynamic> rawList =
            (json['messages'] as List<dynamic>?) ?? const <dynamic>[];
        return GameLogBatchMessage(
          messages: rawList.whereType<Map>().map((dynamic m) {
            final Map<String, dynamic> entry = m is Map<String, dynamic>
                ? m
                : Map<String, dynamic>.from(m as Map);
            return GameLogMessage.fromJson(entry);
          }).toList(),
        );
      case 'game_client':
        return GameClientMessage.fromJson(json);
      case 'html':
        return HtmlMessage.fromJson(json);
      case 'update_spectators':
        return UpdateSpectatorsMessage.fromJson(json);
      case 'chat':
        return ChatMessage.fromJson(json);
      case 'options':
        return OptionsMessage(payload: Map<String, dynamic>.from(json));
      case 'layout':
        return LayoutMessage.fromJson(json);
      case 'ui_state':
        return UiStateMessage.fromJson(json);
      default:
        return UnknownMessage(
          rawType: type,
          payload: Map<String, dynamic>.from(json),
        );
    }
  }
}

abstract class DcssOutgoingMessage {
  const DcssOutgoingMessage();

  Map<String, dynamic> toJson();

  String toRawJson() => jsonEncode(toJson());
}

class LoginRequest extends DcssOutgoingMessage {
  const LoginRequest({required this.username, required this.password});

  final String username;
  final String password;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'msg': 'login',
      'username': username,
      'password': password,
    };
  }
}

class PlayRequest extends DcssOutgoingMessage {
  const PlayRequest({required this.gameId});

  final String gameId;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'msg': 'play',
      'game_id': gameId,
    };
  }
}

class PongRequest extends DcssOutgoingMessage {
  const PongRequest();

  @override
  Map<String, dynamic> toJson() {
    return const <String, dynamic>{
      'msg': 'pong',
    };
  }
}

class KeyPressRequest extends DcssOutgoingMessage {
  const KeyPressRequest({required this.keycode});

  final int keycode;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'msg': 'key',
      'keycode': keycode,
    };
  }
}

class InputRequest extends DcssOutgoingMessage {
  const InputRequest({required this.text});

  final String text;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'msg': 'input',
      'text': text,
    };
  }
}

class TileClickRequest extends DcssOutgoingMessage {
  const TileClickRequest({
    required this.x,
    required this.y,
    this.button = 1,
  });

  final int x;
  final int y;
  final int button;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'msg': 'click',
      'x': x,
      'y': y,
      'button': button,
    };
  }
}

class InputModeMessage extends DcssMessage {
  const InputModeMessage({required this.mode});
  final int mode;
  @override
  String get type => 'input_mode';
}

class SetGameLinksMessage extends DcssMessage {
  const SetGameLinksMessage({required this.gameIds});
  final List<String> gameIds;
  @override
  String get type => 'set_game_links';

  static List<String> _parseGameIds(String html) {
    final RegExp re = RegExp(r'#play-([\w.\-]+)'); // ← add . to charset
    return re.allMatches(html).map((m) => m.group(1)!).toSet().toList();
  }

  factory SetGameLinksMessage.fromJson(Map<String, dynamic> json) {
    final String content = json['content']?.toString() ?? '';
    return SetGameLinksMessage(gameIds: _parseGameIds(content));
  }
}

class GameStartedMessage extends DcssMessage {
  const GameStartedMessage();
  @override
  String get type => 'game_started';
}

class GoLobbyMessage extends DcssMessage {
  const GoLobbyMessage();
  @override
  String get type => 'go_lobby';
}

class GameLogBatchMessage extends DcssMessage {
  const GameLogBatchMessage({required this.messages});

  final List<GameLogMessage> messages;

  @override
  String get type => 'msgs';
}

class GameClientMessage extends DcssMessage {
  const GameClientMessage({required this.version, required this.package});
  final String version;  // the hex hash
  final String package;

  @override String get type => 'game_client';

  factory GameClientMessage.fromJson(Map<String, dynamic> json) {
    debugPrint('[GameClient] keys: ${json.keys.toList()}');
    return GameClientMessage(
      version: _asString(json['version']),
      package: _asString(json['package']),
    );
  }
}

class HtmlMessage extends DcssMessage {
  const HtmlMessage({required this.id, required this.content});

  final String id;
  final String content;

  @override
  String get type => 'html';

  factory HtmlMessage.fromJson(Map<String, dynamic> json) {
    return HtmlMessage(
      id: _asString(json['id']),
      content: _asString(json['content']),
    );
  }
}

class UpdateSpectatorsMessage extends DcssMessage {
  const UpdateSpectatorsMessage({required this.count, required this.names});

  final int count;
  final List<String> names;

  @override
  String get type => 'update_spectators';

  factory UpdateSpectatorsMessage.fromJson(Map<String, dynamic> json) {
    final List<String> nameList = _asStringList(json['names'] ?? json['spectators']);
    return UpdateSpectatorsMessage(
      count: _asInt(json['count']),
      names: nameList,
    );
  }
}

class ChatMessage extends DcssMessage {
  const ChatMessage({required this.sender, required this.text, required this.turn});

  final String sender;
  final String text;
  final int turn;

  @override
  String get type => 'chat';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      sender: _asString(json['sender']),
      text: _asString(json['text']),
      turn: _asInt(json['turn']),
    );
  }
}

class OptionsMessage extends DcssMessage {
  const OptionsMessage({required this.payload});

  final Map<String, dynamic> payload;

  @override
  String get type => 'options';
}

class LayoutMessage extends DcssMessage {
  const LayoutMessage({required this.layout});

  final String layout;

  @override
  String get type => 'layout';

  factory LayoutMessage.fromJson(Map<String, dynamic> json) {
    // DCSS sends either 'layout' or 'layer' as the key name
    final String layout = _asString(json['layout'] ?? json['layer']);
    return LayoutMessage(layout: layout);
  }
}

class UiStateMessage extends DcssMessage {
  const UiStateMessage({required this.uiState, required this.payload});

  final String uiState;
  final Map<String, dynamic> payload;

  @override
  String get type => 'ui_state';

  factory UiStateMessage.fromJson(Map<String, dynamic> json) {
    return UiStateMessage(
      uiState: _asString(json['state']),
      payload: Map<String, dynamic>.from(json),
    );
  }
}