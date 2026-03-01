import 'package:flutter/material.dart';

import 'key_button.dart';
import 'keyboard_action.dart';

class ActLayer extends StatelessWidget {
  const ActLayer({
    super.key,
    required this.onAction,
  });

  final ValueChanged<KeyboardAction> onAction;

  static const List<_ActionDef> _actions = <_ActionDef>[
    _ActionDef('i', 'Inv', 105),
    _ActionDef('d', 'Drop', 100),
    _ActionDef('g', 'Pick', 103),
    _ActionDef('e', 'Eat', 101),
    _ActionDef('z', 'Spell', 122),
    _ActionDef('a', 'Abil', 97),
    _ActionDef('f', 'Fire', 102),
    _ActionDef('t', 'Throw', 116),
    _ActionDef('r', 'Read', 114),
    _ActionDef('q', 'Quaff', 113),
    _ActionDef('w', 'Wear', 119),
    _ActionDef('T', 'Rmv', 84),
    _ActionDef('>', 'Down', 62),
    _ActionDef('<', 'Up', 60),
    _ActionDef('O', 'Open', 79),
    _ActionDef('C', 'Close', 67),
  ];

  static const int _crossAxisCount = 4;
  static const double _paddingH = 6.0;
  static const double _paddingV = 4.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // List.length is not a compile-time constant in Dart, so compute at runtime
        final int rowCount =
            (_actions.length + _crossAxisCount - 1) ~/ _crossAxisCount;
        final double cellWidth =
            (constraints.maxWidth - _paddingH * 2) / _crossAxisCount;
        final double cellHeight =
            (constraints.maxHeight - _paddingV * 2) / rowCount;
        final double aspectRatio = (cellWidth / cellHeight).clamp(0.5, 3.0);

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: _paddingH,
            vertical: _paddingV,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _crossAxisCount,
            childAspectRatio: aspectRatio,
          ),
          itemCount: _actions.length,
          itemBuilder: (BuildContext context, int index) {
            final _ActionDef action = _actions[index];
            return DcssKeyButton(
              keyLabel: action.key,
              subtitle: action.label,
              onTap: () => onAction(KeyboardAction.keycode(action.keycode)),
            );
          },
        );
      },
    );
  }
}

class _ActionDef {
  const _ActionDef(this.key, this.label, this.keycode);

  final String key;
  final String label;
  final int keycode;
}
