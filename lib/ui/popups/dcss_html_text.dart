import 'package:flutter/material.dart';

import '../dcss_text_util.dart';
import 'popup_theme.dart';

/// Widget that renders DCSS HTML/color-tagged text as rich Flutter text.
///
/// Handles `<white>`, `<lightred>`, etc. color tags and strips any
/// remaining HTML tags that aren't DCSS color codes.
class DcssHtmlText extends StatelessWidget {
  const DcssHtmlText({
    super.key,
    required this.text,
    this.defaultColor = PopupTheme.bodyColor,
    this.fontSize = PopupTheme.bodyFontSize,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final Color defaultColor;
  final double fontSize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    // Split into lines and render each, preserving line breaks.
    final List<String> lines = text.split('\n');
    final List<InlineSpan> spans = <InlineSpan>[];

    for (int i = 0; i < lines.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));
      final String line = _stripNonColorHtml(lines[i]);
      spans.addAll(
        DcssTextUtil.parseColoredText(line, defaultColor, fontSize: fontSize),
      );
    }

    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: TextStyle(
          fontFamily: PopupTheme.fontFamily,
          fontSize: fontSize,
          height: 1.4,
        ),
        children: spans,
      ),
    );
  }

  /// Strip HTML tags that aren't DCSS color tags.
  /// DCSS color tags are like <white>, </white>, <lightred>, etc.
  /// Other tags like <span>, <br>, <b>, <div> should be stripped.
  static String _stripNonColorHtml(String text) {
    // First replace <br> and <br/> with newlines
    String result = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    // Strip non-color HTML tags (anything that's not a known DCSS color name)
    result = result.replaceAllMapped(
      RegExp(r'<(/?)(\w+)(?:\s[^>]*)?>'),
      (Match match) {
        final String tagName = match.group(2)!.toLowerCase();
        if (DcssTextUtil.tagNameToColor(tagName) != null) {
          // Keep DCSS color tags
          return match.group(0)!;
        }
        // Strip everything else
        return '';
      },
    );
    return result;
  }
}
