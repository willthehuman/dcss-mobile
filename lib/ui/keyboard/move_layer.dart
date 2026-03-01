import 'package:flutter/material.dart';

import 'key_button.dart';
import 'keyboard_action.dart';

class MoveLayer extends StatelessWidget {
  const MoveLayer({
    super.key,
    required this.onAction,
  });

  final ValueChanged<KeyboardAction> onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Column(
        children: <Widget>[
          Expanded(
            child: _buildRow(
              <Widget>[
                _directionButton('7', '↖', 55),
                _directionButton('8', '↑', 56),
                _directionButton('9', '↗', 57),
              ],
            ),
          ),
          Expanded(
            child: _buildRow(
              <Widget>[
                _directionButton('4', '←', 52),
                Expanded(
                  child: DcssKeyButton(
                    keyLabel: '5',
                    subtitle: '·',
                    onTap: () => onAction(const KeyboardAction.character('.')),
                  ),
                ),
                _directionButton('6', '→', 54),
              ],
            ),
          ),
          Expanded(
            child: _buildRow(
              <Widget>[
                _directionButton('1', '↙', 49),
                _directionButton('2', '↓', 50),
                _directionButton('3', '↘', 51),
              ],
            ),
          ),
          Expanded(
            child: _buildRow(
              <Widget>[
                Expanded(
                  child: DcssKeyButton(
                    keyLabel: 'o',
                    subtitle: 'explore',
                    onTap: () => onAction(const KeyboardAction.character('o')),
                  ),
                ),
                Expanded(
                  child: DcssKeyButton(
                    keyLabel: 'Tab',
                    subtitle: 'attack',
                    onTap: () => onAction(const KeyboardAction.keycode(9)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _directionButton(String keyLabel, String direction, int keycode) {
    return Expanded(
      child: DcssKeyButton(
        keyLabel: keyLabel,
        subtitle: direction,
        onTap: () => onAction(KeyboardAction.keycode(keycode)),
      ),
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Row(children: children);
  }
}
