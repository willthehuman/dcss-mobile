import 'package:flutter/material.dart';

import 'dcss_html_text.dart';
import 'popup_scaffold.dart';
import 'popup_theme.dart';

/// Popup for `describe-monster` ui-push messages.
///
/// Shows monster name, HD, HP estimate, speed, threat level, description,
/// spellsets, status effects, and optional quote/flavor text.
class DescribeMonsterPopup extends StatelessWidget {
  const DescribeMonsterPopup({
    super.key,
    required this.payload,
    required this.onKeycode,
  });

  final Map<String, dynamic> payload;
  final ValueChanged<int> onKeycode;

  @override
  Widget build(BuildContext context) {
    final String title =
        (payload['title'] ?? payload['name'] ?? 'Monster').toString();

    return PopupScaffold(
      title: title,
      onKeycode: onKeycode,
      child: SingleChildScrollView(
        padding: PopupTheme.popupPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Main body text
            if (_hasField('body'))
              DcssHtmlText(text: payload['body'].toString()),
            if (_hasField('text'))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DcssHtmlText(text: payload['text'].toString()),
              ),
            if (_hasField('description'))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DcssHtmlText(text: payload['description'].toString()),
              ),

            // Status section
            if (_hasField('status')) ...<Widget>[
              const SizedBox(height: 12),
              const DcssHtmlText(
                text: '<yellow>--- Status ---</yellow>',
                defaultColor: PopupTheme.accentColor,
              ),
              const SizedBox(height: 4),
              DcssHtmlText(text: payload['status'].toString()),
            ],

            // Quote / flavor text
            if (_hasField('quote')) ...<Widget>[
              const SizedBox(height: 12),
              DcssHtmlText(
                text: payload['quote'].toString(),
                defaultColor: PopupTheme.mutedColor,
              ),
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
