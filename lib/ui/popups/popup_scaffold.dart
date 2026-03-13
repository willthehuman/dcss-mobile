import 'package:flutter/material.dart';

import 'popup_theme.dart';

/// Shared scaffold layout for all DCSS popup overlays.
///
/// Provides a dark modal container with optional title, scrollable body,
/// and a dismiss-on-tap-outside behavior that sends ESC to the server.
class PopupScaffold extends StatelessWidget {
  const PopupScaffold({
    super.key,
    this.title,
    required this.onKeycode,
    this.maxHeightFraction = 0.85,
    this.maxWidthFraction = 0.95,
    this.showCloseHint = true,
    required this.child,
  });

  final String? title;
  final ValueChanged<int> onKeycode;
  final double maxHeightFraction;
  final double maxWidthFraction;
  final bool showCloseHint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onKeycode(27), // ESC
        child: Container(
          color: PopupTheme.background,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: GestureDetector(
            onTap: () {}, // absorb taps inside the popup
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: screenSize.height * maxHeightFraction,
                maxWidth: screenSize.width * maxWidthFraction,
              ),
              child: Container(
                decoration: PopupTheme.popupDecoration,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (title != null && title!.isNotEmpty)
                      _buildHeader(context),
                    Flexible(child: child),
                    if (showCloseHint) _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PopupTheme.divider)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(title!, style: PopupTheme.titleStyle),
          ),
          IconButton(
            onPressed: () => onKeycode(27),
            icon: const Icon(Icons.close, color: PopupTheme.mutedColor, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PopupTheme.divider)),
      ),
      child: const Text(
        'Tap outside or press ESC to close',
        style: TextStyle(
          color: PopupTheme.mutedColor,
          fontSize: 11,
          fontFamily: PopupTheme.fontFamily,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
