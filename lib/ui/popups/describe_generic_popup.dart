import 'package:flutter/material.dart';

import 'dcss_html_text.dart';
import 'popup_scaffold.dart';
import 'popup_theme.dart';

/// Generic descriptive text popup.
///
/// Used for miscellaneous descriptions that don't match a more specific type.
/// Renders title + body text in a scrollable modal.
class DescribeGenericPopup extends StatelessWidget {
  const DescribeGenericPopup({
    super.key,
    required this.payload,
    required this.onKeycode,
  });

  final Map<String, dynamic> payload;
  final ValueChanged<int> onKeycode;

  @override
  Widget build(BuildContext context) {
    final String title = _extractTitle();
    final String body = _extractBody();

    return PopupScaffold(
      title: title,
      onKeycode: onKeycode,
      child: SingleChildScrollView(
        padding: PopupTheme.popupPadding,
        child: DcssHtmlText(text: body),
      ),
    );
  }

  String _extractTitle() {
    return (payload['title'] ?? payload['prompt'] ?? '').toString();
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
}
