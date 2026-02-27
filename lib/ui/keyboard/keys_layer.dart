import 'package:flutter/material.dart';

import 'key_button.dart';
import 'keyboard_action.dart';

class KeysLayer extends StatelessWidget {
  const KeysLayer({
    super.key,
    required this.onAction,
  });

  final ValueChanged<KeyboardAction> onAction;

  static const List<String> _numbers = <String>[
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '0',
  ];

  static const List<String> _rowQwerty = <String>[
    'q',
    'w',
    'e',
    'r',
    't',
    'y',
    'u',
    'i',
    'o',
    'p',
  ];

  static const List<String> _rowAsdf = <String>[
    'a',
    's',
    'd',
    'f',
    'g',
    'h',
    'j',
    'k',
    'l',
  ];

  static const List<String> _rowZxcv = <String>[
    'z',
    'x',
    'c',
    'v',
    'b',
    'n',
    'm',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        children: <Widget>[
          Expanded(child: _buildRow(_numbers)),
          Expanded(child: _buildRow(_rowQwerty)),
          Expanded(child: _buildRow(_rowAsdf, leadingSpacer: 1, trailingSpacer: 0)),
          Expanded(child: _buildRow(_rowZxcv, leadingSpacer: 2, trailingSpacer: 1)),
        ],
      ),
    );
  }

  Widget _buildRow(
    List<String> keys, {
    int leadingSpacer = 0,
    int trailingSpacer = 0,
  }) {
    final List<Widget> children = <Widget>[];

    for (int i = 0; i < leadingSpacer; i += 1) {
      children.add(const Spacer());
    }

    for (final String key in keys) {
      children.add(
        Expanded(
          child: DcssKeyButton(
            keyLabel: key,
            onTap: () => onAction(KeyboardAction.character(key)),
          ),
        ),
      );
    }

    for (int i = 0; i < trailingSpacer; i += 1) {
      children.add(const Spacer());
    }

    return Row(children: children);
  }
}
