import 'package:flutter/material.dart';

import 'dcss_html_text.dart';
import 'popup_scaffold.dart';
import 'popup_theme.dart';

/// Popup for `describe-cards` ui-push messages.
///
/// Nemelex card deck descriptions. Similar structure to other
/// describe popups - title + body in a scrollable modal.
class DescribeCardsPopup extends StatelessWidget {
  const DescribeCardsPopup({
    super.key,
    required this.payload,
    required this.onKeycode,
  });

  final Map<String, dynamic> payload;
  final ValueChanged<int> onKeycode;

  @override
  Widget build(BuildContext context) {
    final String title =
        (payload['title'] ?? payload['name'] ?? 'Cards').toString();

    return PopupScaffold(
      title: title,
      onKeycode: onKeycode,
      child: SingleChildScrollView(
        padding: PopupTheme.popupPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final String key in <String>['body', 'text', 'description'])
              if (_hasField(key)) ...<Widget>[
                DcssHtmlText(text: payload[key].toString()),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  bool _hasField(String key) {
    final dynamic val = payload[key];
    return val != null && val.toString().isNotEmpty;
  }
}
