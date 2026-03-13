import 'package:flutter/material.dart';

import 'dcss_html_text.dart';
import 'popup_scaffold.dart';
import 'popup_theme.dart';

/// Popup for `describe-god` ui-push messages.
///
/// Shows god name, piety level, favour status, powers list,
/// and wrath description. May receive `ui-state` updates to
/// refresh piety info live.
class DescribeGodPopup extends StatelessWidget {
  const DescribeGodPopup({
    super.key,
    required this.payload,
    required this.onKeycode,
  });

  final Map<String, dynamic> payload;
  final ValueChanged<int> onKeycode;

  @override
  Widget build(BuildContext context) {
    final String title =
        (payload['title'] ?? payload['name'] ?? 'God').toString();

    return PopupScaffold(
      title: title,
      onKeycode: onKeycode,
      child: SingleChildScrollView(
        padding: PopupTheme.popupPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Main body / description
            for (final String key in <String>['body', 'text', 'description'])
              if (_hasField(key)) ...<Widget>[
                DcssHtmlText(text: payload[key].toString()),
                const SizedBox(height: 8),
              ],

            // Favour / piety
            if (_hasField('favour')) ...<Widget>[
              const SizedBox(height: 4),
              DcssHtmlText(
                text: '<lightcyan>Favour:</lightcyan> ${payload['favour']}',
              ),
            ],

            // Powers
            if (_hasField('powers')) ...<Widget>[
              const SizedBox(height: 12),
              const DcssHtmlText(
                text: '<yellow>--- Powers ---</yellow>',
                defaultColor: PopupTheme.accentColor,
              ),
              const SizedBox(height: 4),
              DcssHtmlText(text: payload['powers'].toString()),
            ],

            // Powers list
            if (_hasField('powers_list')) ...<Widget>[
              const SizedBox(height: 4),
              DcssHtmlText(text: payload['powers_list'].toString()),
            ],

            // Wrath
            if (_hasField('wrath')) ...<Widget>[
              const SizedBox(height: 12),
              const DcssHtmlText(
                text: '<lightred>--- Wrath ---</lightred>',
                defaultColor: Color(0xFFFF5555),
              ),
              const SizedBox(height: 4),
              DcssHtmlText(text: payload['wrath'].toString()),
            ],

            // Info table
            if (_hasField('info_table')) ...<Widget>[
              const SizedBox(height: 8),
              DcssHtmlText(text: payload['info_table'].toString()),
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
