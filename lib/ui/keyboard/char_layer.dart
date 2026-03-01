import 'package:flutter/material.dart';

import 'key_button.dart';
import 'keyboard_action.dart';

class CharLayer extends StatelessWidget {
  const CharLayer({
    super.key,
    required this.onAction,
  });

  final ValueChanged<KeyboardAction> onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        children: <Widget>[
          Expanded(
            child: _row(<Widget>[
              _key('@', 'Status', 64),
              _key('m', 'Skills', 109),
              _key('A', 'Mutatns', 65),
              _key('^', 'Religion', 94),
            ]),
          ),
          Expanded(
            child: _row(<Widget>[
              _key('%', 'Resist', 37),
              _key('I', 'SpellLib', 73),
              _key('E', 'Equip', 69),
              _key('\\', 'Discov', 92),
            ]),
          ),
          Expanded(
            child: _row(<Widget>[
              Expanded(
                child: DcssKeyButton(
                  keyLabel: 'Ctrl+A',
                  subtitle: 'Ann',
                  onTap: () => onAction(const KeyboardAction.keycode(1)),
                ),
              ),
              Expanded(
                child: DcssKeyButton(
                  keyLabel: 'Ctrl+O',
                  subtitle: 'Ovrl',
                  onTap: () => onAction(const KeyboardAction.keycode(15)),
                ),
              ),
            ]),
          ),
          Expanded(
            child: _row(<Widget>[
              _key('(', 'Worn', 40),
              _key(')', 'Inv', 41),
              _key('{', 'Runes', 123),
              _key('}', 'CollKey', 125),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _key(String key, String label, int keycode) {
    return Expanded(
      child: DcssKeyButton(
        keyLabel: key,
        subtitle: label,
        onTap: () => onAction(KeyboardAction.keycode(keycode)),
      ),
    );
  }

  Widget _row(List<Widget> children) {
    return Row(children: children);
  }
}
