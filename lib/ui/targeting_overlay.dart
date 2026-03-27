import 'package:flutter/material.dart';

/// Slim overlay shown when the game is in examine/targeting mode (`x`).
///
/// - Top banner: mode label + [ESC] exit button.
/// - Bottom action bar: Describe (`v`) + Exit (ESC).
///
/// Movement is handled by:
///   1. Tapping any tile on the map (tile-click sent to server).
///   2. The Move-tab number keys on the keyboard panel (remapped to vi-keys
///      by game_screen.dart while [isInTargetingMode] is true).
class TargetingOverlay extends StatelessWidget {
  const TargetingOverlay({
    super.key,
    required this.onKeycode,
    required this.onExit,
  });

  final ValueChanged<int> onKeycode;
  final VoidCallback onExit;

  static const int _kDescribe = 118;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Column(
          children: <Widget>[
            _buildBanner(),
            const Spacer(),
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xCC1A1A2E),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: <Widget>[
          const Icon(Icons.gps_fixed, color: Color(0xFF55FFFF), size: 14),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Examine mode — tap a tile to move cursor',
              style: TextStyle(
                color: Color(0xFF55FFFF),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          GestureDetector(
            onTap: onExit,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Text(
                '[ESC] Exit',
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      color: const Color(0xDD111111),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _actionButton(
            label: 'Describe [v]',
            icon: Icons.info_outline,
            color: const Color(0xFF55FFFF),
            onTap: () => onKeycode(_kDescribe),
          ),
          const SizedBox(width: 12),
          _actionButton(
            label: 'Exit [ESC]',
            icon: Icons.close,
            color: const Color(0xFF888888),
            onTap: onExit,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
