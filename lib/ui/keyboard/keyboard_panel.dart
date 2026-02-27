import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/keycode_helpers.dart';
import 'act_layer.dart';
import 'char_layer.dart';
import 'keyboard_action.dart';
import 'keyboard_layer.dart';
import 'keys_layer.dart';
import 'layer_tab_bar.dart';
import 'modifier_strip.dart';
import 'more_layer.dart';
import 'move_layer.dart';

class KeyboardPanel extends StatefulWidget {
  const KeyboardPanel({
    super.key,
    required this.onKeycode,
    this.hapticsEnabled = true,
  });

  final ValueChanged<int> onKeycode;
  final bool hapticsEnabled;

  @override
  State<KeyboardPanel> createState() => _KeyboardPanelState();
}

class _KeyboardPanelState extends State<KeyboardPanel> {
  KeyboardLayer _activeLayer = KeyboardLayer.move;
  bool _ctrlActive = false;
  bool _shiftActive = false;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: <Widget>[
          ModifierStrip(
            ctrlActive: _ctrlActive,
            shiftActive: _shiftActive,
            onCtrlTap: _toggleCtrl,
            onShiftTap: _toggleShift,
            onEnterTap: () => _sendRawKeycode(13),
            onEscTap: () => _sendRawKeycode(27),
            onQuestionTap: () => _sendRawKeycode(63),
          ),
          Expanded(child: _buildActiveLayer()),
          LayerTabBar(
            activeLayer: _activeLayer,
            onLayerSelected: (KeyboardLayer layer) {
              setState(() {
                _activeLayer = layer;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveLayer() {
    switch (_activeLayer) {
      case KeyboardLayer.move:
        return MoveLayer(onAction: _handleAction);
      case KeyboardLayer.act:
        return ActLayer(onAction: _handleAction);
      case KeyboardLayer.char:
        return CharLayer(onAction: _handleAction);
      case KeyboardLayer.more:
        return MoreLayer(onAction: _handleAction);
      case KeyboardLayer.keys:
        return KeysLayer(onAction: _handleAction);
    }
  }

  void _toggleCtrl() {
    setState(() {
      _ctrlActive = !_ctrlActive;
    });
  }

  void _toggleShift() {
    setState(() {
      _shiftActive = !_shiftActive;
    });
  }

  void _handleAction(KeyboardAction action) {
    int keycode = 0;

    if (action.keycode != null) {
      keycode = action.keycode!;
    } else if (action.character != null && action.character!.isNotEmpty) {
      final bool useCtrl = _ctrlActive || action.forceCtrl;
      final bool useShift = !useCtrl && _shiftActive;
      keycode = keycodeForCharacter(
        action.character!,
        applyCtrl: useCtrl,
        applyShift: useShift,
      );
    }

    if (keycode == 0) {
      return;
    }

    _emitKeycode(keycode, consumeModifiers: true);
  }

  void _sendRawKeycode(int keycode) {
    _emitKeycode(keycode, consumeModifiers: true);
  }

  void _emitKeycode(int keycode, {required bool consumeModifiers}) {
    if (widget.hapticsEnabled) {
      HapticFeedback.lightImpact();
    }

    widget.onKeycode(keycode);

    if (consumeModifiers && (_ctrlActive || _shiftActive)) {
      setState(() {
        _ctrlActive = false;
        _shiftActive = false;
      });
    }
  }
}
