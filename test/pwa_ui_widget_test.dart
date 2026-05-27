import 'package:dcss_mobile/game/game_state.dart';
import 'package:dcss_mobile/ui/keyboard/keyboard_panel.dart';
import 'package:dcss_mobile/ui/message_log_widget.dart';
import 'package:dcss_mobile/ui/text_input_overlay.dart';
import 'package:dcss_mobile/ui/txt_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder richText(String text) {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is RichText && widget.text.toPlainText() == text,
    description: 'RichText with "$text"',
  );
}

void main() {
  testWidgets('keyboard modifiers emit shifted and control keycodes once',
      (WidgetTester tester) async {
    final List<int> keycodes = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 320,
            child: KeyboardPanel(onKeycode: keycodes.add),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Keys'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SHIFT'));
    await tester.pump();
    await tester.tap(find.text('a'));
    await tester.pump();
    await tester.tap(find.text('a'));
    await tester.pump();

    await tester.tap(find.text('CTRL'));
    await tester.pump();
    await tester.tap(find.text('b'));
    await tester.pump();

    expect(keycodes, <int>[65, 97, 2]);
  });

  testWidgets('message log displays WebTiles more prompt over latest message',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageLogWidget(
            messages: <GameMessage>[
              GameMessage(
                text: 'You climb downwards.',
                channel: 0,
                timestamp: DateTime(2026),
              ),
            ],
            fontSize: 14,
            morePrompt: '--more--',
          ),
        ),
      ),
    );

    expect(richText('--more--'), findsOneWidget);
    expect(richText('You climb downwards.'), findsNothing);
  });

  testWidgets('text input overlay submits a carriage-return terminated line',
      (WidgetTester tester) async {
    String? submitted;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              TextInputOverlay(
                inputState: const TextInputState(
                  tag: 'name',
                  inputType: 'generic',
                  prompt: 'Name:',
                ),
                onSubmit: (String text) => submitted = text,
                onDismiss: () {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Beogh');
    await tester.tap(find.text('OK'));
    await tester.pump();

    expect(submitted, 'Beogh\r');
  });

  testWidgets('txt overlay renders lines and sends escape on tap',
      (WidgetTester tester) async {
    final List<int> keycodes = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              TxtOverlay(
                payload: <String, dynamic>{
                  'lines': <dynamic>[
                    <dynamic>[
                      <dynamic>['A scroll of identify', 15],
                    ],
                  ],
                },
                onKeycode: keycodes.add,
              ),
            ],
          ),
        ),
      ),
    );

    expect(richText('A scroll of identify'), findsOneWidget);
    await tester.tap(find.byType(TxtOverlay));
    await tester.pump();

    expect(keycodes, <int>[27]);
  });
}
