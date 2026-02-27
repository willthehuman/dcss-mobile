import 'package:flutter/material.dart';

import 'key_button.dart';

class ModifierStrip extends StatelessWidget {
  const ModifierStrip({
    super.key,
    required this.ctrlActive,
    required this.shiftActive,
    required this.onCtrlTap,
    required this.onShiftTap,
    required this.onEnterTap,
    required this.onEscTap,
    required this.onQuestionTap,
  });

  final bool ctrlActive;
  final bool shiftActive;
  final VoidCallback onCtrlTap;
  final VoidCallback onShiftTap;
  final VoidCallback onEnterTap;
  final VoidCallback onEscTap;
  final VoidCallback onQuestionTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: <Widget>[
          Expanded(
            child: DcssKeyButton(
              keyLabel: 'CTRL',
              onTap: onCtrlTap,
              active: ctrlActive,
            ),
          ),
          Expanded(
            child: DcssKeyButton(
              keyLabel: 'SHIFT',
              onTap: onShiftTap,
              active: shiftActive,
            ),
          ),
          Expanded(
            child: DcssKeyButton(
              keyLabel: 'ENTER',
              onTap: onEnterTap,
            ),
          ),
          Expanded(
            child: DcssKeyButton(
              keyLabel: 'ESC',
              onTap: onEscTap,
            ),
          ),
          Expanded(
            child: DcssKeyButton(
              keyLabel: '?',
              onTap: onQuestionTap,
            ),
          ),
        ],
      ),
    );
  }
}
