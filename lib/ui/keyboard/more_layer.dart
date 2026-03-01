import 'package:flutter/material.dart';

import 'key_button.dart';
import 'keyboard_action.dart';

class MoreLayer extends StatelessWidget {
  const MoreLayer({
    super.key,
    required this.onAction,
  });

  final ValueChanged<KeyboardAction> onAction;

  static const int _crossAxisCount = 4;
  static const double _paddingH = 6.0;
  static const double _paddingV = 4.0;
  // 16 items / 4 columns = 4 rows
  static const int _rowCount =
      (_moreActions.length + _crossAxisCount - 1) ~/ _crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cellWidth =
            (constraints.maxWidth - _paddingH * 2) / _crossAxisCount;
        final double cellHeight =
            (constraints.maxHeight - _paddingV * 2) / _rowCount;
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
          itemCount: _moreActions.length,
          itemBuilder: (BuildContext context, int index) {
            final _MoreAction action = _moreActions[index];
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

class _MoreAction {
  const _MoreAction(this.key, this.label, this.keycode);

  final String key;
  final String label;
  final int keycode;
}

const List<_MoreAction> _moreActions = <_MoreAction>[
  _MoreAction('S', 'Save', 83),
  _MoreAction('Q', 'Quit', 81),
  _MoreAction('!', 'Shout', 33),
  _MoreAction(':', 'Note', 58),
  _MoreAction('X', 'Map', 88),
  _MoreAction('Ctrl+P', 'Log', 16),
  _MoreAction('Ctrl+F', 'Srch', 6),
  _MoreAction('Ctrl+E', 'Evk', 5),
  _MoreAction('v', 'Exmn', 118),
  _MoreAction(';', 'Travel', 59),
  _MoreAction('Ctrl+X', 'Ext', 24),
  _MoreAction('=', 'Assign', 61),
  _MoreAction('Ctrl+C', 'Cls', 3),
  _MoreAction('P', 'Pray', 80),
  _MoreAction('_', 'Floor', 95),
  _MoreAction('~', 'Macro', 126),
];
