import 'dart:convert';

import 'package:dcss_mobile/network/dcss_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('outgoing WebTiles messages', () {
    test('uses upstream click_cell for tile taps', () {
      final Map<String, dynamic> json =
          jsonDecode(const TileClickRequest(x: 12, y: 34).toRawJson())
              as Map<String, dynamic>;

      expect(json, <String, dynamic>{
        'msg': 'click_cell',
        'x': 12,
        'y': 34,
        'button': 1,
      });
    });

    test('keeps login, play, key, input, and text_input wire shapes', () {
      expect(
        jsonDecode(
          const LoginRequest(username: 'user', password: 'pw').toRawJson(),
        ),
        <String, dynamic>{
          'msg': 'login',
          'username': 'user',
          'password': 'pw',
        },
      );
      expect(jsonDecode(const PlayRequest(gameId: 'dcss-web-trunk').toRawJson()),
          <String, dynamic>{'msg': 'play', 'game_id': 'dcss-web-trunk'});
      expect(jsonDecode(const KeyPressRequest(keycode: 27).toRawJson()),
          <String, dynamic>{'msg': 'key', 'keycode': 27});
      expect(jsonDecode(const InputRequest(text: 'o').toRawJson()),
          <String, dynamic>{'msg': 'input', 'text': 'o'});
      expect(jsonDecode(const TextInputRequest(text: 'abc\r').toRawJson()),
          <String, dynamic>{'msg': 'text_input', 'text': 'abc\r'});
    });
  });

  group('incoming WebTiles messages', () {
    test('parses current upstream player stat names and structured statuses', () {
      final PlayerUpdateMessage message = PlayerUpdateMessage.fromJson(
        <String, dynamic>{
          'hp': 10,
          'hp_max': 14,
          'mp': 3,
          'mp_max': 7,
          'status': <Map<String, dynamic>>[
            <String, dynamic>{'light': 'Pois', 'col': 10},
            <String, dynamic>{'text': 'Slow', 'col': 12},
          ],
          'pos': <String, dynamic>{'x': 4, 'y': 9},
        },
      );

      expect(message.hp, 10);
      expect(message.mhp, 14);
      expect(message.mp, 3);
      expect(message.mmp, 7);
      expect(message.status, <String>['Pois', 'Slow']);
      expect(message.x, 4);
      expect(message.y, 9);
    });

    test('keeps legacy mhp/mmp stat names as fallbacks', () {
      final PlayerUpdateMessage message = PlayerUpdateMessage.fromJson(
        <String, dynamic>{'mhp': 11, 'mmp': 5},
      );

      expect(message.mhp, 11);
      expect(message.mmp, 5);
    });

    test('parses message batches with rollback and more prompts', () {
      final DcssMessage message = DcssMessageFactory.fromJson(
        <String, dynamic>{
          'msg': 'msgs',
          'rollback': 1,
          'old_msgs': 2,
          'more': true,
          'more_text': '--more--',
          'messages': <Map<String, dynamic>>[
            <String, dynamic>{'text': 'You climb downwards.', 'channel': 0},
          ],
        },
      );

      expect(message, isA<GameLogBatchMessage>());
      final GameLogBatchMessage batch = message as GameLogBatchMessage;
      expect(batch.rollback, 1);
      expect(batch.oldMsgs, 2);
      expect(batch.more, isTrue);
      expect(batch.moreText, '--more--');
      expect(batch.messages.single.text, 'You climb downwards.');
    });

    test('accepts both ui_state and ui-state variants', () {
      final DcssMessage underscore = DcssMessageFactory.fromJson(
        <String, dynamic>{'msg': 'ui_state', 'state': 2},
      );
      final DcssMessage hyphen = DcssMessageFactory.fromJson(
        <String, dynamic>{'msg': 'ui-state', 'type': 'formatted-scroller'},
      );

      expect(underscore, isA<UiStateMessage>());
      expect((underscore as UiStateMessage).uiState, '2');
      expect(hyphen, isA<UiStateMessage>());
      expect((hyphen as UiStateMessage).uiState, 'formatted-scroller');
    });
  });
}
