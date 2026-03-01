import 'package:flutter/material.dart';

import '../game/game_state.dart';

class MessageLogWidget extends StatelessWidget {
  const MessageLogWidget({
    super.key,
    required this.messages,
    required this.fontSize,
  });

  final List<GameMessage> messages;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final GameMessage? latest = messages.isEmpty ? null : messages.last;
    final Color channelColor = _channelToColor(latest?.channel ?? 0);

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => _showLogSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: _parseColoredText(
                  latest?.text ?? 'No messages yet.',
                  channelColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLogSheet(BuildContext context) {
    final List<GameMessage> recent =
        messages.length <= 100 ? messages : messages.sublist(messages.length - 100);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: recent.length,
              itemBuilder: (BuildContext context, int index) {
                final GameMessage msg = recent[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: RichText(
                    text: TextSpan(
                      children: _parseColoredText(
                        msg.text,
                        _channelToColor(msg.channel),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Parses DCSS-style color tags (e.g. `<white>text</white>`, `<lightblue>x</lightblue>`)
  /// into a list of [TextSpan]s with proper Flutter [Color]s.
  /// Text outside any tag is rendered with [defaultColor].
  List<TextSpan> _parseColoredText(String text, Color defaultColor) {
    final List<TextSpan> spans = <TextSpan>[];
    final RegExp tagRegex = RegExp(r'<(/?)(\w+)>');

    int lastEnd = 0;
    Color currentColor = defaultColor;
    final List<Color> colorStack = <Color>[];

    for (final RegExpMatch match in tagRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: currentColor, fontSize: fontSize),
        ));
      }

      final bool isClosing = match.group(1) == '/';
      final String tagName = match.group(2)!.toLowerCase();

      if (!isClosing) {
        final Color? tagColor = _tagNameToColor(tagName);
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
  /// Returns null for unrecognised tags (color is left unchanged).
  Color? _tagNameToColor(String tag) {
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
        return const Color(0xFFB8860B); // dark goldenrod — DCSS "brown"
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
        return Colors.orange.shade300; // DCSS lightred renders as bright orange
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

  Color _channelToColor(int channel) {
    switch (channel) {
      case 1:
        return Colors.grey.shade300;
      case 4:
        return Colors.yellow.shade300;
      case 7:
        return Colors.red.shade300;
      case 9:
        return Colors.lightBlue.shade200;
      case 0:
      default:
        return Colors.white;
    }
  }
}
