import 'package:flutter/material.dart';

import 'dcss_html_text.dart';
import 'popup_scaffold.dart';
import 'popup_theme.dart';

/// Popup for `describe-feature-wide` ui-push messages.
///
/// Dungeon feature descriptions (altars, shops, stairs, etc.).
/// Wider format with support for a list of feature entries.
class DescribeFeaturePopup extends StatelessWidget {
  const DescribeFeaturePopup({
    super.key,
    required this.payload,
    required this.onKeycode,
  });

  final Map<String, dynamic> payload;
  final ValueChanged<int> onKeycode;

  @override
  Widget build(BuildContext context) {
    final String title =
        (payload['title'] ?? payload['prompt'] ?? 'Feature').toString();

    return PopupScaffold(
      title: title,
      onKeycode: onKeycode,
      child: SingleChildScrollView(
        padding: PopupTheme.popupPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Main body text
            for (final String key in <String>['body', 'text', 'description'])
              if (_hasField(key)) ...<Widget>[
                DcssHtmlText(text: payload[key].toString()),
                const SizedBox(height: 8),
              ],

            // Feats list (describe-feature-wide specific)
            if (payload['feats'] is List)
              ..._buildFeats(payload['feats'] as List<dynamic>),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFeats(List<dynamic> feats) {
    final List<Widget> widgets = <Widget>[];
    for (final dynamic feat in feats) {
      if (feat is Map) {
        final String? featTitle = feat['title']?.toString();
        final String? featBody = feat['body']?.toString();
        if (featTitle != null && featTitle.isNotEmpty) {
          widgets.add(const SizedBox(height: 8));
          widgets.add(DcssHtmlText(
            text: featTitle,
            defaultColor: PopupTheme.titleColor,
            fontSize: PopupTheme.bodyFontSize + 1,
          ));
        }
        if (featBody != null && featBody.isNotEmpty) {
          widgets.add(const SizedBox(height: 4));
          widgets.add(DcssHtmlText(text: featBody));
        }
      } else if (feat is String) {
        widgets.add(const SizedBox(height: 4));
        widgets.add(DcssHtmlText(text: feat));
      }
    }
    return widgets;
  }

  bool _hasField(String key) {
    final dynamic val = payload[key];
    return val != null && val.toString().isNotEmpty;
  }
}
