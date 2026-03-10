import 'package:flutter/material.dart';

import 'dcss_html_text.dart';
import 'popup_scaffold.dart';
import 'popup_theme.dart';

/// Popup for `newgame-random-combo` ui-push messages.
///
/// Shows the randomly generated combo and asks for confirmation.
/// Simple dialog with accept/reject buttons.
class NewgameRandomComboPopup extends StatelessWidget {
  const NewgameRandomComboPopup({
    super.key,
    required this.payload,
    required this.onKeycode,
  });

  final Map<String, dynamic> payload;
  final ValueChanged<int> onKeycode;

  @override
  Widget build(BuildContext context) {
    final String title =
        (payload['title'] ?? 'Random Character').toString();
    final String body = _extractBody();

    return PopupScaffold(
      title: title,
      onKeycode: onKeycode,
      showCloseHint: false,
      maxHeightFraction: 0.45,
      child: Padding(
        padding: PopupTheme.popupPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (body.isNotEmpty)
              DcssHtmlText(text: body),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onKeycode(13), // Enter = accept
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PopupTheme.accentColor,
                      side: const BorderSide(color: PopupTheme.accentColor),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Accept [Enter]',
                      style: TextStyle(
                        fontFamily: PopupTheme.fontFamily,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onKeycode(27), // ESC = reject
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PopupTheme.mutedColor,
                      side: const BorderSide(color: PopupTheme.divider),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Reject [ESC]',
                      style: TextStyle(
                        fontFamily: PopupTheme.fontFamily,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _extractBody() {
    final StringBuffer buf = StringBuffer();
    for (final String key in <String>[
      'body', 'text', 'description', 'prompt'
    ]) {
      final String? val = payload[key]?.toString();
      if (val != null && val.isNotEmpty) {
        if (buf.isNotEmpty) buf.write('\n\n');
        buf.write(val);
      }
    }
    return buf.toString();
  }
}
