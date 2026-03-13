import 'package:flutter/material.dart';

import 'dcss_html_text.dart';
import 'popup_scaffold.dart';
import 'popup_theme.dart';

/// Popup for `describe-item` ui-push messages.
///
/// Shows item name, description, stats, brand, artefact properties,
/// and optional action buttons (wield, wear, drop, etc.) that send
/// keypress commands to the server.
class DescribeItemPopup extends StatelessWidget {
  const DescribeItemPopup({
    super.key,
    required this.payload,
    required this.onKeycode,
  });

  final Map<String, dynamic> payload;
  final ValueChanged<int> onKeycode;

  @override
  Widget build(BuildContext context) {
    final String title =
        (payload['title'] ?? payload['name'] ?? 'Item').toString();
    final String body = _extractBody();
    final List<_ActionButton> actions = _parseActions();

    return PopupScaffold(
      title: title,
      onKeycode: onKeycode,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Flexible(
            child: SingleChildScrollView(
              padding: PopupTheme.popupPadding,
              child: DcssHtmlText(text: body),
            ),
          ),
          if (actions.isNotEmpty) _buildActions(actions),
        ],
      ),
    );
  }

  String _extractBody() {
    final StringBuffer buf = StringBuffer();
    for (final String key in <String>['body', 'text', 'description']) {
      final String? val = payload[key]?.toString();
      if (val != null && val.isNotEmpty) {
        if (buf.isNotEmpty) buf.write('\n\n');
        buf.write(val);
      }
    }
    return buf.toString();
  }

  List<_ActionButton> _parseActions() {
    final List<_ActionButton> result = <_ActionButton>[];
    final dynamic actions = payload['actions'];
    if (actions is List) {
      for (final dynamic action in actions) {
        if (action is Map) {
          final String label =
              (action['label'] ?? action['text'] ?? '').toString();
          int hotkey = 0;
          final dynamic hk = action['hotkey'];
          if (hk is int) {
            hotkey = hk;
          } else if (hk is String && hk.isNotEmpty) {
            hotkey = hk.codeUnitAt(0);
          }
          if (label.isNotEmpty && hotkey > 0) {
            result.add(_ActionButton(label: label, hotkey: hotkey));
          }
        }
      }
    }
    return result;
  }

  Widget _buildActions(List<_ActionButton> actions) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PopupTheme.divider)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: actions.map((_ActionButton action) {
          final String keyLabel = String.fromCharCode(action.hotkey);
          return OutlinedButton(
            onPressed: () => onKeycode(action.hotkey),
            style: OutlinedButton.styleFrom(
              foregroundColor: PopupTheme.actionColor,
              side: const BorderSide(color: PopupTheme.divider),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '[$keyLabel] ${action.label}',
              style: const TextStyle(
                fontFamily: PopupTheme.fontFamily,
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActionButton {
  const _ActionButton({required this.label, required this.hotkey});
  final String label;
  final int hotkey;
}
