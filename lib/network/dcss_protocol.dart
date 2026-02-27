import 'dart:convert';

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
  const MapCellDelta({required this.x, required this.y, required this.tiles});

  final int x;
  final int y;
  final List<int> tiles;

  factory MapCellDelta.fromJson(Map<String, dynamic> json) {
    return MapCellDelta(
      x: _asInt(json['x']),
      y: _asInt(json['y']),
      tiles: _asIntList(json['t']),
    );
  }

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
  });

  final List<MapCellDelta> cells;
  final int? playerX;
  final int? playerY;

  @override
  String get type => 'map';

  factory MapUpdateMessage.fromJson(Map<String, dynamic> json) {
    final dynamic cellsRaw = json['cells'];
    final List<MapCellDelta> parsedCells = <MapCellDelta>[];
    if (cellsRaw is List) {
      for (final dynamic cell in cellsRaw) {
        if (cell is Map<String, dynamic>) {
          parsedCells.add(MapCellDelta.fromJson(cell));
        } else if (cell is Map) {
          parsedCells.add(
            MapCellDelta.fromJson(cell.cast<String, dynamic>()),
          );
        }
      }
    }

    final int? x = json.containsKey('player_x')
        ? _asInt(json['player_x'])
        : (json.containsKey('px') ? _asInt(json['px']) : null);
    final int? y = json.containsKey('player_y')
        ? _asInt(json['player_y'])
        : (json.containsKey('py') ? _asInt(json['py']) : null);

    return MapUpdateMessage(cells: parsedCells, playerX: x, playerY: y);
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
          parsedItems.add(MenuItemMessage.fromJson(item.cast<String, dynamic>()));
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
      case 'txt':
        return TxtMessage(payload: Map<String, dynamic>.from(json));
      case 'version':
        return VersionMessage(payload: Map<String, dynamic>.from(json));
      case 'lobby_entry':
        return LobbyEntryMessage(payload: Map<String, dynamic>.from(json));
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

class GetLobbiedGamesRequest extends DcssOutgoingMessage {
  const GetLobbiedGamesRequest();

  @override
  Map<String, dynamic> toJson() {
    return const <String, dynamic>{
      'msg': 'get_lobbied_games',
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
