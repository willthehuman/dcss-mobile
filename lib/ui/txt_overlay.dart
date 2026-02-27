import 'dart:math';

import 'package:flutter/material.dart';

const List<Color> _dcssColors = <Color>[
  Color(0xFF000000), // 0: black
  Color(0xFF0000AA), // 1: blue
  Color(0xFF00AA00), // 2: green
  Color(0xFF00AAAA), // 3: cyan
  Color(0xFFAA0000), // 4: red
  Color(0xFFAA00AA), // 5: magenta
  Color(0xFFAA5500), // 6: brown
  Color(0xFFAAAAAA), // 7: light gray
  Color(0xFF555555), // 8: dark gray
  Color(0xFF5555FF), // 9: light blue
  Color(0xFF55FF55), // 10: light green
  Color(0xFF55FFFF), // 11: light cyan
  Color(0xFFFF5555), // 12: light red
  Color(0xFFFF55FF), // 13: light magenta
  Color(0xFFFFFF55), // 14: yellow
  Color(0xFFFFFFFF), // 15: white
];

class _TxtSpan {
  const _TxtSpan({required this.text, this.fg = 7, this.bg = 0});

  final String text;
  final int fg;
  final int bg;
}

class TxtOverlay extends StatelessWidget {
  const TxtOverlay({
    super.key,
    required this.payload,
    required this.onKeycode,
  });

  final Map<String, dynamic> payload;
  final ValueChanged<int> onKeycode;

  @override
  Widget build(BuildContext context) {
    final List<List<_TxtSpan>> lines = _parseLines(payload);
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onKeycode(27),
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.all(6),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines.map(_buildLine).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLine(List<_TxtSpan> spans) {
    if (spans.isEmpty || (spans.length == 1 && spans.first.text.isEmpty)) {
      return const SizedBox(height: 16);
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.3,
        ),
        children: spans.map((_TxtSpan span) {
          final Color fg = _dcssColors[span.fg.clamp(0, 15)];
          final Color? bg =
              span.bg > 0 ? _dcssColors[span.bg.clamp(0, 15)] : null;

          return TextSpan(
            text: span.text,
            style: TextStyle(
              color: fg,
              backgroundColor: bg,
            ),
          );
        }).toList(),
      ),
    );
  }

  static List<List<_TxtSpan>> _parseLines(Map<String, dynamic> payload) {
    final dynamic rawLines = payload['lines'];
    if (rawLines == null) {
      return <List<_TxtSpan>>[];
    }

    final Map<int, dynamic> lineMap = <int, dynamic>{};

    if (rawLines is Map) {
      for (final dynamic key in rawLines.keys) {
        final int? row = int.tryParse(key.toString());
        if (row != null) {
          lineMap[row] = rawLines[key];
        }
      }
    } else if (rawLines is List) {
      for (int i = 0; i < rawLines.length; i++) {
        lineMap[i] = rawLines[i];
      }
    } else {
      return <List<_TxtSpan>>[];
    }

    if (lineMap.isEmpty) {
      return <List<_TxtSpan>>[];
    }

    final int maxRow = lineMap.keys.reduce(max);
    final List<List<_TxtSpan>> result = <List<_TxtSpan>>[];

    for (int row = 0; row <= maxRow; row++) {
      final dynamic lineData = lineMap[row];
      if (lineData == null) {
        result.add(const <_TxtSpan>[_TxtSpan(text: '')]);
        continue;
      }
      result.add(_parseLine(lineData));
    }

    return result;
  }

  static List<_TxtSpan> _parseLine(dynamic lineData) {
    if (lineData is String) {
      return <_TxtSpan>[_TxtSpan(text: lineData)];
    }
    if (lineData is! List) {
      return <_TxtSpan>[_TxtSpan(text: lineData.toString())];
    }

    final List<_TxtSpan> spans = <_TxtSpan>[];
    for (final dynamic span in lineData) {
      if (span is String) {
        spans.add(_TxtSpan(text: span));
      } else if (span is List) {
        final String text = span.isNotEmpty ? span[0].toString() : '';
        final int fg = span.length > 1 ? _safeInt(span[1], 7) : 7;
        final int bg = span.length > 2 ? _safeInt(span[2], 0) : 0;
        spans.add(_TxtSpan(text: text, fg: fg, bg: bg));
      } else if (span is Map) {
        final String text =
            (span['text'] ?? span['t'] ?? span['ch'] ?? '').toString();
        final int fg = _safeInt(span['fg'], 7);
        final int bg = _safeInt(span['bg'], 0);
        spans.add(_TxtSpan(text: text, fg: fg, bg: bg));
      }
    }

    return spans.isEmpty ? const <_TxtSpan>[_TxtSpan(text: '')] : spans;
  }

  static int _safeInt(dynamic value, int fallback) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }
}
