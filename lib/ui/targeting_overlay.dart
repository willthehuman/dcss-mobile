import 'package:flutter/material.dart';

/// Overlay shown when the game is in examine/targeting mode (after pressing `x`).
///
/// Provides:
/// - A semi-transparent banner at the top indicating targeting mode is active.
/// - A D-pad with 8-directional arrow buttons to move the cursor.
/// - An "Examine" button to send `v`/Enter and trigger the describe popup.
/// - An "Exit" (ESC) button to leave targeting mode.
///
/// DCSS numpad keycodes used for movement (vi-keys fallback also accepted):
///   7=NW, 8=N, 9=NE, 4=W, 6=E, 1=SW, 2=S, 3=SE
/// We send the numpad key codes via the `onKeycode` callback.
class TargetingOverlay extends StatelessWidget {
  const TargetingOverlay({
    super.key,
    required this.onKeycode,
    required this.onExit,
  });

  final ValueChanged<int> onKeycode;
  final VoidCallback onExit;

  // Numpad keycodes (sent as-is to the DCSS webtiles server)
  static const int _kNW = 55; // numpad 7
  static const int _kN = 56;  // numpad 8
  static const int _kNE = 57; // numpad 9
  static const int _kW = 52;  // numpad 4
  static const int _kE = 54;  // numpad 6
  static const int _kSW = 49; // numpad 1
  static const int _kS = 50;  // numpad 2
  static const int _kSE = 51; // numpad 3
  static const int _kEnter = 13; // Enter = describe selected tile
  static const int _kEsc = 27;   // ESC = exit targeting mode

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Column(
          children: <Widget>[
            // Top banner
            _buildBanner(),
            const Spacer(),
            // D-pad + action buttons at bottom
            _buildControls(),
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
          const Icon(Icons.gps_fixed, color: Color(0xFF55FFFF), size: 16),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Examine mode — navigate cursor, tap tile, or use buttons below',
              style: TextStyle(
                color: Color(0xFF55FFFF),
                fontSize: 12,
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

  Widget _buildControls() {
    return Container(
      color: const Color(0xDD111111),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _buildDpad(),
          const SizedBox(width: 12),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildDpad() {
    return SizedBox(
      width: 110,
      height: 110,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _dirButton('↖', _kNW),
              _dirButton('↑', _kN),
              _dirButton('↗', _kNE),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _dirButton('←', _kW),
              _centerDot(),
              _dirButton('→', _kE),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _dirButton('↙', _kSW),
              _dirButton('↓', _kS),
              _dirButton('↘', _kSE),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dirButton(String label, int keycode) {
    return GestureDetector(
      onTap: () => onKeycode(keycode),
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: const Color(0xFF222233),
          border: Border.all(color: const Color(0xFF444455)),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _centerDot() {
    return Container(
      width: 34,
      height: 34,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border.all(color: const Color(0xFF333344)),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: const Text(
        '·',
        style: TextStyle(color: Color(0xFF555566), fontSize: 18),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _actionButton(
          label: 'Describe [v]',
          icon: Icons.info_outline,
          color: const Color(0xFF55FFFF),
          onTap: () => onKeycode(_kEnter),
        ),
        const SizedBox(height: 8),
        _actionButton(
          label: 'Exit [ESC]',
          icon: Icons.close,
          color: const Color(0xFF888888),
          onTap: onExit,
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
