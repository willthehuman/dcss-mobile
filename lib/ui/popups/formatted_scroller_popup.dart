import 'package:flutter/material.dart';

import 'dcss_html_text.dart';
import 'popup_scaffold.dart';
import 'popup_theme.dart';

/// Popup for `formatted-scroller` ui-push messages.
///
/// Used for help screens (`?`), ability list (`a`), mutation list (`A`), etc.
/// Large scrollable text content with DCSS color formatting.
/// Near full-screen overlay.
class FormattedScrollerPopup extends StatelessWidget {
  const FormattedScrollerPopup({
    super.key,
    required this.payload,
    required this.onKeycode,
  });

  final Map<String, dynamic> payload;
  final ValueChanged<int> onKeycode;

  @override
  Widget build(BuildContext context) {
    final String title = (payload['title'] ?? '').toString();
    final String body = _extractBody();

    return PopupScaffold(
      title: title.isNotEmpty ? title : null,
      onKeycode: onKeycode,
      maxHeightFraction: 0.92,
      child: SingleChildScrollView(
        padding: PopupTheme.popupPadding,
        child: DcssHtmlText(text: body),
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

    // formatted-scroller may also have a 'more' prompt
    final String? more = payload['more']?.toString();
    if (more != null && more.isNotEmpty) {
      if (buf.isNotEmpty) buf.write('\n\n');
      buf.write(more);
    }

    return buf.toString();
  }
}
