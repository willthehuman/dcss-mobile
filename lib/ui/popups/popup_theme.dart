import 'package:flutter/material.dart';

/// Shared theme constants for all DCSS popup overlays.
class PopupTheme {
  PopupTheme._();

  static const Color background = Color(0xF0111111);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color divider = Color(0xFF333333);
  static const Color titleColor = Colors.white;
  static const Color bodyColor = Color(0xFFAAAAAA);
  static const Color accentColor = Color(0xFF55FFFF); // light cyan
  static const Color mutedColor = Color(0xFF555555);
  static const Color actionColor = Color(0xFFFFFF55); // yellow

  static const double titleFontSize = 16;
  static const double bodyFontSize = 13;
  static const String fontFamily = 'monospace';

  static const EdgeInsets popupPadding = EdgeInsets.all(12);
  static const BorderRadius borderRadius =
      BorderRadius.all(Radius.circular(8));

  static BoxDecoration get popupDecoration => BoxDecoration(
        color: surface,
        borderRadius: borderRadius,
        border: Border.all(color: divider),
      );

  static TextStyle get titleStyle => const TextStyle(
        color: titleColor,
        fontSize: titleFontSize,
        fontFamily: fontFamily,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get bodyStyle => const TextStyle(
        color: bodyColor,
        fontSize: bodyFontSize,
        fontFamily: fontFamily,
        height: 1.4,
      );

  static TextStyle get mutedStyle => const TextStyle(
        color: mutedColor,
        fontSize: bodyFontSize,
        fontFamily: fontFamily,
        fontStyle: FontStyle.italic,
      );
}
