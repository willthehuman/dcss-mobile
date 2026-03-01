import 'package:flutter/material.dart';

/// Shared utility for parsing DCSS formatted text with color tags
/// like `<white>text</white>` or `<lightgreen>text</lightgreen>`.
class DcssTextUtil {
  DcssTextUtil._();

  static final RegExp _tagRegex = RegExp(r'<(/?)(\w+)>');

  /// Parse DCSS colour-tagged text into a list of [TextSpan]s.
  static List<TextSpan> parseColoredText(
    String text,
    Color defaultColor, {
    double fontSize = 13,
  }) {
    final List<TextSpan> spans = <TextSpan>[];
    int lastEnd = 0;
    Color currentColor = defaultColor;
    final List<Color> colorStack = <Color>[];

    for (final RegExpMatch match in _tagRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: currentColor, fontSize: fontSize),
        ));
      }

      final bool isClosing = match.group(1) == '/';
      final String tagName = match.group(2)!.toLowerCase();

      if (!isClosing) {
        final Color? tagColor = tagNameToColor(tagName);
        if (tagColor != null) {
          colorStack.add(currentColor);
          currentColor = tagColor;
        }
      } else {
        if (colorStack.isNotEmpty) {
          currentColor = colorStack.removeLast();
        } else {
          currentColor = defaultColor;
        }
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(color: currentColor, fontSize: fontSize),
      ));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(
        text: text,
        style: TextStyle(color: defaultColor, fontSize: fontSize),
      ));
    }

    return spans;
  }

  /// Maps a DCSS color tag name to a Flutter [Color].
  static Color? tagNameToColor(String tag) {
    switch (tag) {
      case 'white':
        return Colors.white;
      case 'lightgrey':
      case 'lightgray':
        return Colors.grey.shade300;
      case 'darkgrey':
      case 'darkgray':
        return Colors.grey.shade600;
      case 'yellow':
        return Colors.yellow.shade300;
      case 'brown':
        return const Color(0xFFB8860B);
      case 'green':
        return Colors.green.shade400;
      case 'lightgreen':
        return Colors.lightGreen.shade300;
      case 'blue':
        return Colors.blue.shade400;
      case 'lightblue':
        return Colors.lightBlue.shade200;
      case 'red':
        return Colors.red.shade400;
      case 'lightred':
        return Colors.orange.shade300;
      case 'magenta':
      case 'purple':
        return Colors.purple.shade300;
      case 'lightmagenta':
        return Colors.pinkAccent.shade100;
      case 'cyan':
        return Colors.cyan.shade400;
      case 'lightcyan':
        return Colors.cyan.shade200;
      case 'black':
        return Colors.black;
      default:
        return null;
    }
  }
}
